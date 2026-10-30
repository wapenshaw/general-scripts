import { atom, read, update } from 'claude-code'
import type { EngineInterface, PluginOptions, Register } from 'claude-code'

import { HANDOFF_PROMPT, withHandoff } from './handoff'

// Compacts an idle session shortly before its prompt cache goes cold, and makes
// every compaction (this one, the engine's threshold, /compact) write a detailed
// handoff document instead of a generic summary.
//
// The cache entry for the conversation lives `ttl` after the last request
// that read or wrote it. Compacting while it is still warm means the
// summarizer reads the transcript from cache (cheap), and the next prompt
// re-caches a short summary instead of the full transcript (expensive).
//
// Status line: a status line command runs as its own process and cannot ask the
// plugin anything, so the plugin writes its state to
// `~/.claude/cold-compact/sessions/<session id>.json` whenever it changes.

const PLUGIN = 'cache-cold-compact'
const TICK_MS = 30_000
const MINUTE = 60_000

const armedAt = atom({ plugin: 'cache-cold-compact', key: 'armedAt' } as const, null)
const isPaused = atom({ plugin: 'cache-cold-compact', key: 'isPaused' } as const, false)

type Config = { ttlMs: number; fireAfterMs: number; minTokens: number; showStatus: boolean }
type Last = { at: number; before: number; after: number }
type StateName = 'idle' | 'armed' | 'compacting' | 'paused'

// Set by register; module variables start over on every (re)load.
let config: Config = { ttlMs: 60 * MINUTE, fireAfterMs: 55 * MINUTE, minTokens: 50_000, showStatus: true }
let isTurnRunning = false
let isCompacting = false
let shownStatus: string | undefined
let stateFile: string | undefined
let publishedKey = ''
let last: Last | null = null

function numberOption(options: PluginOptions, key: string, fallback: number) {
  const value = Number(options[key])
  return Number.isFinite(value) && value > 0 ? value : fallback
}

function minutesLabel(ms: number) {
  return `${Math.max(1, Math.ceil(ms / MINUTE))}m`
}

function setStatus($: EngineInterface, text: string | undefined) {
  if (!config.showStatus && text !== undefined) return
  if (text === shownStatus) return
  shownStatus = text
  $.ui.status(text)
}

/** Resolves where the status line reads this session's state from; silent when it cannot. */
async function resolveStateFile($: EngineInterface) {
  try {
    const id = await $.session.id()
    const dir = await homeDir($)
    stateFile = dir && id ? `${dir}/.claude/cold-compact/sessions/${id}.json` : undefined
  } catch {
    stateFile = undefined
  }
}

/** HOME on macOS/Linux; Windows has no printenv or HOME outside Git Bash, so fall back to USERPROFILE. */
async function homeDir($: EngineInterface) {
  for (const argv of [['printenv', 'HOME'], ['cmd', '/d', '/c', 'echo %USERPROFILE%']]) {
    try {
      const out = await $.process.run(argv)
      const dir = out.exitCode === 0 ? out.stdout.trim() : ''
      if (dir && !dir.includes('%')) return dir.replaceAll('\\', '/')
    } catch {
      // Not on this platform; try the next one.
    }
  }
  return ''
}

/** Writes the state for the status line, skipping a write that would say the same thing. */
async function publish($: EngineInterface, state: StateName, fireAtMs = 0) {
  if (!stateFile) return
  const fireAt = Math.floor(fireAtMs / 1000)
  const key = `${state}|${fireAt}|${last?.at ?? 0}`
  if (key === publishedKey) return
  publishedKey = key

  const now = Math.floor((await $.clock.now()) / 1000)
  const body = { state, fireAt, ttlSeconds: Math.round(config.ttlMs / 1000), last, updatedAt: now }
  try {
    await $.fs.write(stateFile, `${JSON.stringify(body)}\n`)
  } catch (error) {
    $.ui.log(`${PLUGIN}: could not write ${stateFile}: ${String(error)}`, { to: 'debug' })
  }
}

async function recordCompaction($: EngineInterface, before: number | undefined, after: number | undefined) {
  const now = await $.clock.now()
  last = { at: Math.floor(now / 1000), before: before ?? 0, after: after ?? 0 }
}

async function disarm($: EngineInterface) {
  await update($, armedAt, () => null)
  setStatus($, undefined)
  await publish($, (await read($, isPaused)) ? 'paused' : 'idle')
}

async function tick($: EngineInterface) {
  if (isTurnRunning || isCompacting) return

  const since = await read($, armedAt)
  if (await read($, isPaused)) {
    setStatus($, undefined)
    await publish($, 'paused')
    return
  }
  if (since === null) {
    setStatus($, undefined)
    await publish($, 'idle')
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
    await publish($, 'armed', since + config.fireAfterMs)
    return
  }

  const { context } = await $.session.usage()
  if ((context.tokens ?? 0) < config.minTokens) {
    await disarm($)
    return
  }

  isCompacting = true
  setStatus($, 'compacting before the prompt cache goes cold…')
  await publish($, 'compacting')
  try {
    // A plugin's own compact() skips its own session.compact hook, so the handoff
    // prompt is passed explicitly here; the hook below covers every other trigger.
    const result = await $.session.compact({ instructions: HANDOFF_PROMPT })
    if (result.skip !== undefined) {
      $.ui.toast(`Auto-compact skipped: ${result.skip}`)
    } else {
      const before = result.tokensBefore ?? context.tokens
      const after = result.tokensAfter
      await recordCompaction($, before, after)
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
    await $.command.register({
      name: 'handoff-compact',
      description: 'Compact now with the handoff-document prompt; optional text adds emphasis',
    })
    await resolveStateFile($)
    publishedKey = ''
    await publish($, 'idle')
    $.clock.every(TICK_MS, () => void tick($))

    return next(e)
  })

  on('turn.start', async ($, e, next) => {
    isTurnRunning = true
    // A turn is running: the cache is being used, nothing is counting down.
    await publish($, (await read($, isPaused)) ? 'paused' : 'idle')
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

  // Every compaction of the main conversation (engine threshold, /compact, a
  // precompute) gets the handoff brief; the person's own text after /compact is kept.
  on('session.compact', async ($, e, next) => {
    const isMain = e.agentId === undefined
    const result = await next(isMain ? { ...e, instructions: withHandoff(e.instructions) } : e)

    // Any compaction of the main conversation replaces the cached prefix.
    if (isMain && e.trigger !== 'precompute' && result.skip === undefined) {
      await recordCompaction($, result.tokensBefore, result.tokensAfter)
      await disarm($)
    }
    return result
  }).catch(($, e, next) =>
    // If this hook ever fails, compact with what it was given rather than block compaction.
    next(e),
  )

  on('session.end', async ($, e, next) => {
    await disarm($)
    return next(e)
  })

  // /compact with the handoff prompt passed explicitly, so it holds even when a
  // hook earlier in the session.compact chain stops this plugin's hook from running.
  on('command.run', { command: 'handoff-compact' }, async ($, e) => {
    isCompacting = true
    try {
      const result = await $.session.compact({ instructions: withHandoff(e.args) })
      if (result.skip !== undefined) return { text: `Handoff compact skipped: ${result.skip}` }
      await recordCompaction($, result.tokensBefore, result.tokensAfter)
      const sizes =
        result.tokensBefore && result.tokensAfter
          ? ` (${Math.round(result.tokensBefore / 1000)}k → ${Math.round(result.tokensAfter / 1000)}k tokens)`
          : ''
      return { text: `Compacted with the handoff prompt${sizes}.` }
    } catch (error) {
      return { text: `Handoff compact did not run: ${String(error)}` }
    } finally {
      isCompacting = false
      await disarm($)
    }
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
    const policy = `fires after ${minutesLabel(config.fireAfterMs)} idle (TTL ${minutesLabel(config.ttlMs)}), contexts ≥ ${Math.round(config.minTokens / 1000)}k tokens; every compaction writes a handoff document`
    if (paused) return { text: `Auto-compact is off for this session; ${policy}.` }
    if (since === null) return { text: `Auto-compact is on, not armed (no large idle context); ${policy}.` }

    const idleMs = (await $.clock.now()) - since
    return { text: `Auto-compact armed: compacts in ${minutesLabel(config.fireAfterMs - idleMs)}; ${policy}.` }
  })
}
