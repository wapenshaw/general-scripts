import { test, expect } from 'claude-code/testing'

import { HANDOFF_PROMPT, MARKER, withHandoff } from './handoff'

test('a bare compaction gets the handoff prompt', () => {
  const out = withHandoff(undefined)

  expect(out).toBe(HANDOFF_PROMPT)
  expect(out).toContain(MARKER)
  expect(out).toContain('HANDOFF DOCUMENT')
  expect(out).toContain('Pending tasks and next steps')
})

test('text typed after /compact is kept as extra emphasis', () => {
  const out = withHandoff('stress the WSL work')

  expect(out).toContain(HANDOFF_PROMPT)
  expect(out).toContain('stress the WSL work')
})

test('blank instructions behave like none', () => {
  expect(withHandoff('   ')).toBe(HANDOFF_PROMPT)
})

test('a prompt already carrying the marker is not wrapped twice', () => {
  const once = withHandoff('x')

  expect(withHandoff(once)).toBe(once)
})
