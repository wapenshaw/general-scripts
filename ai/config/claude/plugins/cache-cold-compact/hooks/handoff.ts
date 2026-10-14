// Marker so a prompt that already went through this hook (a precompute whose
// instructions come back around) is never wrapped twice.
export const MARKER = '[handoff-compact]'

export const HANDOFF_PROMPT = `${MARKER}
Write this summary as a HANDOFF DOCUMENT. A fresh instance of yourself, with no memory of this conversation and no access to it, must be able to read only this document and continue the work without asking the user to repeat anything. Be detailed and concrete. Prefer exact paths, commands, identifiers, error text and values over paraphrase. Never write "as discussed" or "the earlier issue": say what it was. Do not pad with pleasantries, and do not omit something because it seems obvious now.

Use these sections, in this order. Write "None" for a section with nothing to report; do not drop it.

## 1. Goal and current state
- The user's original request in their own terms, then how it evolved (new asks, changed minds, dropped scope).
- One paragraph: where the work stands right now, and what was being done in the last few turns.

## 2. Decisions and constraints
- Every decision the user made, with the reason when given. Mark each as FINAL (do not re-litigate) or OPEN.
- Instructions, preferences and corrections the user gave about HOW to work (style, tools, things to never do, things they pushed back on). Quote short phrases verbatim where the wording matters.
- Project rules in force that shaped the work (for example commit/push policy, no-cd, naming), and any approvals that were scoped to one action and must not be assumed to extend.

## 3. Work completed
- What was actually changed or run, as facts: files created/edited/deleted with full paths, commands run and their outcome, branches/commits/PRs with names or hashes, environment or config changes, things installed or removed.
- Distinguish clearly: DONE and VERIFIED (say how), DONE but UNVERIFIED, ATTEMPTED and FAILED (with the exact error).

## 4. Exact state of the world
- Working directory and repo/branch, uncommitted or unpushed changes, running processes, temporary files and where scratch output lives.
- Anything left in a non-default or half-finished state that the next instance could trip over (partial edits, locks, open worktrees, background jobs).

## 5. Pending tasks and next steps
- A numbered list, in the order to do them, each specific enough to act on without further context. Say which are blocked, and on what (a user decision, a command only the user can run, an external system).
- The single most useful next action, stated first.

## 6. Findings worth keeping
- Non-obvious facts learned: root causes, how a system actually behaves, where something lives, why an approach was rejected, retracted claims and what replaced them.
- Gotchas and environment quirks that cost time (aliases, options, permissions, hooks that block things) and the workaround.

## 7. Open questions and risks
- Things not yet decided or verified, assumptions made without confirmation, and anything that could be wrong.

## 8. Key references
- Files, directories, commands, URLs, IDs, branch names, session or tool-result paths needed to pick the work back up, each with a one-line note on why it matters.
- If a full transcript or log path is known, list it so details can be recovered.

Rules for the whole document: keep the user's voice and intent intact; do not invent anything not in the conversation; state uncertainty explicitly; keep exact identifiers verbatim. Length is not a goal, but completeness is: a thorough, structured document is expected here, not a short recap.`

/** The instructions the summarizer should get for one compaction of the main conversation. */
export function withHandoff(instructions: string | undefined): string {
  // Already ours (e.g. a kept precompute result coming back around): never wrap twice.
  if (instructions?.includes(MARKER)) return instructions
  const extra = instructions?.trim()
  return extra
    ? `${HANDOFF_PROMPT}\n\nAdditional emphasis requested for this compaction (treat as the highest priority inside the sections above):\n${extra}`
    : HANDOFF_PROMPT
}
