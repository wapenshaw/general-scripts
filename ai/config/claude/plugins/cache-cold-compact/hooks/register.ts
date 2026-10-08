import { atom, read, update } from 'claude-code'
import type { EngineInterface, PluginOptions, Register } from 'claude-code'

// Compacts an idle session shortly before its prompt cache goes cold.
//
// The cache entry for the conversation lives `ttl` after the last request
// that read or wrote it. Compacting while it is still warm means the
// summarizer reads the transcript from cache (cheap), and the next prompt
// re-caches a short summary instead of the full transcript (expensive).

const PLUGIN = 'cache-cold-compact'
const TICK_MS = 30_000
const MINUTE = 60_000

const armedAt = atom({ plugin: 'cache-cold-compact', key: 'armedAt' } as const, null)
const isPaused = atom({ plugin: 'cache-cold-compact', key: 'isPaused' } as const, false)

type Config = { ttlMs: number; fireAfterMs: number; minTokens: number; showStatus: boolean }

// Set by register; module variables start over on every (re)load.
let config: Config = { ttlMs: 60 * MINUTE, fireAfterMs: 55 * MINUTE, minTokens: 50_000, showStatus: true }
let isTurnRunning = false
let isCompacting = false
let shownStatus: string | undefined

function numberOption(options: PluginOptions, key: string, fallback: number) {
  const value = Number(options[key])
  return Number.isFinite(value) && value > 0 ? value : fallback
}

function minutesLabel(ms: number) {
  return `${Math.max(1, Math.ceil(ms / MINUTE))}m`
}

function setStatus($: EngineInterface, text: string | undefined) {
  if (text === shownStatus) return
  shownStatus = text
  $.ui.status(text)
}

async function disarm($: EngineInterface) {
  await update($, armedAt, () => null)
  setStatus($, undefined)
}

async function tick($: EngineInterface) {
  if (isTurnRunning || isCompacting) return

  const since = await read($, armedAt)
  if (since === null || (await read($, isPaused))) {
    setStatus($, undefined)
    return
  }

  const idleMs = (await $.clock.now()) - since
  if (idleMs >= config.ttlMs) {
    // Already cold (the machine slept through the window): nothing to save.
    await disarm($)
    return
  }

  if (idleMs < config.fireAfterMs) {
    setStatus($, config.showStatus ? `auto-compact in ${minutesLabel(config.fireAfterMs - idleMs)}` : undefined)
    return
  }

  const { context } = await $.session.usage()
  if ((context.tokens ?? 0) < config.minTokens) {
    await disarm($)
    return
  }

  isCompacting = true
  setStatus($, 'compacting before the prompt cache goes cold…')
  try {
    const result = await $.session.compact()
    if (result.skip !== undefined) {
      $.ui.toast(`Auto-compact skipped: ${result.skip}`)
    } else {
      const before = result.tokensBefore ?? context.tokens
      const after = result.tokensAfter
      const sizes = before && after ? ` (${Math.round(before / 1000)}k → ${Math.round(after / 1000)}k tokens)` : ''
      $.ui.toast(`Compacted before the prompt cache went cold${sizes}`, { timeoutMs: 8000 })
    }
  } catch (error) {
    // A turn started between the check and the call; turn.complete re-arms.
    $.ui.log(`${PLUGIN}: compact did not run: ${String(error)}`, { to: 'debug' })
  } finally {
    isCompacting = false
    await disarm($)
  }
}

export const register: Register = (on, options) => {
  const ttlMs = numberOption(options, 'ttlMinutes', 60) * MINUTE
  const leadMs = numberOption(options, 'leadMinutes', 5) * MINUTE
  config = {
    ttlMs,
    // With the 5-minute cache "5 minutes before cold" is right after the reply,
    // so never fire before half the TTL of idle time has passed.
    fireAfterMs: Math.max(ttlMs - leadMs, ttlMs / 2),
    minTokens: numberOption(options, 'minContextTokens', 50_000),
    showStatus: options.showStatus !== false,
  }

  on('session.start', async ($, e, next) => {
    await $.command.register({
      name: 'cold-compact',
      description: 'Auto-compact before the prompt cache goes cold: status, or `on` / `off` for this session',
    })
    $.clock.every(TICK_MS, () => void tick($))

    return next(e)
  })

  on('turn.start', ($, e, next) => {
    isTurnRunning = true
    return next(e)
  })

  on('turn.complete', async ($, e, next) => {
    const result = await next(e)
    if (e.agentId !== undefined) return result

    isTurnRunning = false
    // An aborted turn or API error may have sent no request; arm anyway, the
    // worst case is compacting a few minutes earlier than strictly needed.
    const { context } = await $.session.usage()
    if ((context.tokens ?? 0) >= config.minTokens) {
      const now = await $.clock.now()
      await update($, armedAt, () => now)
      await tick($)
    } else {
      await disarm($)
    }

    return result
  })

  on('session.compact', async ($, e, next) => {
    const result = await next(e)
    // Any compaction of the main conversation replaces the cached prefix.
    if (e.agentId === undefined && e.trigger !== 'precompute' && result.skip === undefined) {
      await disarm($)
    }
    return result
  })

  on('session.end', async ($, e, next) => {
    await disarm($)
    return next(e)
  })

  on('command.run', { command: 'cold-compact' }, async ($, e) => {
    const arg = e.args.trim().toLowerCase()
    if (arg === 'off' || arg === 'on') {
      await update($, isPaused, () => arg === 'off')
      await tick($)
      return { text: `Auto-compact before cache goes cold: ${arg} for this session.` }
    }

    const paused = await read($, isPaused)
    const since = await read($, armedAt)
    const policy = `fires after ${minutesLabel(config.fireAfterMs)} idle (TTL ${minutesLabel(config.ttlMs)}), contexts ≥ ${Math.round(config.minTokens / 1000)}k tokens`
    if (paused) return { text: `Auto-compact is off for this session; ${policy}.` }
    if (since === null) return { text: `Auto-compact is on, not armed (no large idle context); ${policy}.` }

    const idleMs = (await $.clock.now()) - since
    return { text: `Auto-compact armed: compacts in ${minutesLabel(config.fireAfterMs - idleMs)}; ${policy}.` }
  })
}
