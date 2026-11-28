---
description: How to write code comments, and what never to comment
---

# Comments

A repository's own comment rules (language specifics such as Rust `// SAFETY:` or Go doc style) come first; these hold wherever they are silent.

- Comment only where intent is not obvious at a glance. A comment that only expands an identifier's name is worse than none.
- **A comment is at most three lines.** Anything longer belongs in the repository's docs, with one line in the code pointing at it.
- Say what the code does plus the why when that is not obvious. Never who calls it or when it runs: call sites move and the comment then lies.
- Never record provenance (which issue, session, probe or commit); that is what `git log` and docs are for. A measured value is worth stating; the session that measured it is not.
- Keep a comment that stops a reader "fixing" the code and breaking it: a measured constant, an external constraint, an ordering that matters, a case that looks unhandled and is not.
- Do not restate what a line already says. Plain words; if a sentence needs a second read, rewrite it shorter.
- In tests, say what the case protects, never what the assertion does.
- Deleting an item deletes its comment.
- As the last step before reporting, check the comments the change added or touched against these rules, editing comments only.
