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
//
// On a Team or Enterprise account the builtin cc-plugin-sec-default sits outermost
// and sends session.compact on past the user tier (next.to "append"), so the
// session.compact hook below never runs and the engine's own compactions get the
// generic summary. Compactions this plugin starts carry the handoff prompt in the
// call itself, so the plugin compacts first: at the end of any turn that leaves
// the context near the engine's threshold, and for /handoff-compact.

const PLUGIN = 'cache-cold-compact'
const TICK_MS = 30_000
const MINUTE = 60_000

const armedAt = atom({ plugin: 'cache-cold-compact', key: 'armedAt' } as const, null)
const isPaused = atom({ plugin: 'cache-cold-compact', key: 'isPaused' } as const, false)

type Config = { ttlMs: number; fireAfterMs: number; minTokens: number; preemptPercent: number; showStatus: boolean }
type Last = { at: number; before: number; after: number }
type StateName = 'idle' | 'armed' | 'compacting' | 'paused'
type Outcome = { sizes: string } | { skip: string } | { error: string }

// Set by register; module variables start over on every (re)load.
let config: Config = { ttlMs: 60 * MINUTE, fireAfterMs: 55 * MINUTE, minTokens: 50_000, preemptPercent: 75, showStatus: true }
let isTurnRunning = false
let isCompacting = false
/** Emphasis text from /handoff-compact, waiting for its turn to end; undefined when none is queued. */
let pendingHandoff: string | undefined
let handoffTries = 0
/** The engine compacts at the smaller of this and the model's window. */
let windowFromEnv: number | undefined
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

/** An environment variable as Claude Code's children see it (settings env included); '' when unset. */
async function envVar($: EngineInterface, name: string) {
  // Native Windows has no printenv; cmd echoes %NAME% back unchanged when it is unset.
  for (const argv of [['printenv', name], ['cmd', '/d', '/c', `echo %${name}%`]]) {
    try {
      const out = await $.process.run(argv)
      const value = out.exitCode === 0 ? out.stdout.trim() : ''
      if (value && !value.includes('%')) return value
    } catch {
      // Not on this platform; try the next one.
    }
  }
  return ''
}

/** HOME on macOS/Linux; Windows has no HOME outside Git Bash, so fall back to USERPROFILE. */
async function homeDir($: EngineInterface) {
  const dir = (await envVar($, 'HOME')) || (await envVar($, 'USERPROFILE'))
  return dir.replaceAll('\\', '/')
}

/** CLAUDE_CODE_AUTO_COMPACT_WINDOW ("350000", "350k", "1m") in tokens; undefined when unset or unreadable. */
async function envCompactWindow($: EngineInterface) {
  const match = /^(\d+(?:\.\d+)?)\s*([km])?$/i.exec(await envVar($, 'CLAUDE_CODE_AUTO_COMPACT_WINDOW'))
  if (!match) return undefined
  const scale = { k: 1_000, m: 1_000_000 }[match[2]?.toLowerCase() ?? ''] ?? 1
  return Math.round(Number(match[1]) * scale) || undefined
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

/** The window the engine's threshold compaction works from: the env cap, when set, under the model's own. */
function engineWindow(modelWindow: number | undefined) {
  if (windowFromEnv === undefined) return modelWindow
  return modelWindow ? Math.min(modelWindow, windowFromEnv) : windowFromEnv
}

// Claude Code 2.1.316 compacts at window - 20k (output reserve) - 13k (buffer) and
// starts precomputing that summary at 80% of window - 20k. 75% of the window lands
// just under the precompute (262k of 350k), so a turn ending past it compacts with
// the handoff prompt before the engine has spent anything on a generic summary.
const ENGINE_RESERVE = 33_000
const ENGINE_MARGIN = 5_000

/** Context size at which a turn's end compacts ahead of the engine; undefined when off or unknown. */
function preemptTokens(modelWindow: number | undefined) {
  const window = engineWindow(modelWindow)
  if (config.preemptPercent <= 0 || !window) return undefined
  const byPercent = Math.floor((window * config.preemptPercent) / 100)
  return Math.max(config.minTokens, Math.min(byPercent, window - ENGINE_RESERVE - ENGINE_MARGIN))
}

const HANDOFF_TRIES = 30
const HANDOFF_POLL_MS = 2_000

/**
 * Runs a queued /handoff-compact. The engine refuses it while the command's turn
 * is held, so this retries from the clock until that turn lets go.
 */
async function flushHandoff($: EngineInterface) {
  if (pendingHandoff === undefined || isCompacting) return
  const emphasis = pendingHandoff
  const outcome = await compactWith($, withHandoff(emphasis))
  if ('error' in outcome && ++handoffTries < HANDOFF_TRIES) return
  pendingHandoff = undefined
  handoffTries = 0
  $.ui.toast(describe('Compacted with the handoff prompt', 'Handoff compact', outcome), { timeoutMs: 8000 })
}

function describe(done: string, name: string, outcome: Outcome) {
  if ('sizes' in outcome) return `${done}${outcome.sizes}`
  if ('skip' in outcome) return `${name} skipped: ${outcome.skip}`
  return `${name} did not run: ${outcome.error}`
}

/** Compacts with the given instructions (they reach the summarizer whoever's hooks run first). */
async function compactWith($: EngineInterface, instructions: string): Promise<Outcome> {
  isCompacting = true
  await publish($, 'compacting')
  try {
    const { context } = await $.session.usage()
    // A plugin's own compact() skips its own session.compact hook, so the
    // handoff prompt always travels in the call.
    const result = await $.session.compact({ instructions })
    if (result.skip !== undefined) return { skip: result.skip }
    const before = result.tokensBefore ?? context.tokens
    const after = result.tokensAfter
    await recordCompaction($, before, after)
    return { sizes: before && after ? ` (${Math.round(before / 1000)}k → ${Math.round(after / 1000)}k tokens)` : '' }
  } catch (error) {
    $.ui.log(`${PLUGIN}: compact did not run: ${String(error)}`, { to: 'debug' })
    return { error: String(error) }
  } finally {
    isCompacting = false
    await disarm($)
  }
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

  setStatus($, 'compacting before the prompt cache goes cold…')
  const outcome = await compactWith($, HANDOFF_PROMPT)
  // An error means a turn started between the check and the call; turn.complete re-arms.
  if (!('error' in outcome)) {
    $.ui.toast(describe('Compacted before the prompt cache went cold', 'Auto-compact', outcome), { timeoutMs: 8000 })
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
    // 0 turns it off; above 100 it could never fire.
    preemptPercent: Math.min(100, Math.max(0, Number(options.preemptPercent ?? 75) || 0)),
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
    windowFromEnv = await envCompactWindow($)
    publishedKey = ''
    await publish($, 'idle')
    $.clock.every(TICK_MS, () => void tick($))
    $.clock.every(HANDOFF_POLL_MS, () => void flushHandoff($))

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
    const { context } = await $.session.usage()

    if (pendingHandoff !== undefined) {
      await flushHandoff($)
      return result
    }

    // Beat the engine's threshold compaction, whose summary skips the handoff
    // prompt when cc-plugin-sec-default passes session.compact on past this plugin.
    const preemptAt = preemptTokens(context.window)
    if (preemptAt !== undefined && (context.tokens ?? 0) >= preemptAt && !(await read($, isPaused))) {
      const outcome = await compactWith($, HANDOFF_PROMPT)
      // Errors (e.g. headless sessions, where plugins cannot compact yet) are in the debug log.
      if (!('error' in outcome)) {
        $.ui.toast(describe('Compacted with the handoff prompt ahead of auto-compact', 'Handoff compact', outcome), {
          timeoutMs: 8000,
        })
      }
      return result
    }

    // An aborted turn or API error may have sent no request; arm anyway, the
    // worst case is compacting a few minutes earlier than strictly needed.
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
  // Skipped entirely while cc-plugin-sec-default is seated (see the top of the file).
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
  // The engine refuses a compact from command.run (it would compact under the turn
  // this hook holds), so it is queued for turn.complete or the clock, whichever comes first.
  on('command.run', { command: 'handoff-compact' }, async ($, e) => {
    pendingHandoff = e.args
    return { text: 'Compacting with the handoff prompt as this turn ends…' }
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
    const { context } = await $.session.usage()
    const preemptAt = preemptTokens(context.window)
    const preempt =
      preemptAt === undefined
        ? 'no compaction ahead of auto-compact'
        : `compacts at turn end from ${Math.round(preemptAt / 1000)}k of the ${Math.round((engineWindow(context.window) ?? 0) / 1000)}k auto-compact window (now ${Math.round((context.tokens ?? 0) / 1000)}k)`
    const policy = `fires after ${minutesLabel(config.fireAfterMs)} idle (TTL ${minutesLabel(config.ttlMs)}), contexts ≥ ${Math.round(config.minTokens / 1000)}k tokens; ${preempt}; compactions it starts write a handoff document`
    if (paused) return { text: `Auto-compact is off for this session; ${policy}.` }
    if (since === null) return { text: `Auto-compact is on, not armed (no large idle context); ${policy}.` }

    const idleMs = (await $.clock.now()) - since
    return { text: `Auto-compact armed: compacts in ${minutesLabel(config.fireAfterMs - idleMs)}; ${policy}.` }
  })
}
