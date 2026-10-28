# Antigravity CLI (`agy`) conversation titles

Antigravity CLI sets no terminal title unless a title command is configured. A Herdr pane
running `agy` then keeps its shell's default title (`C:\Program Files\PowerShell\7\pwsh.exe`
on Windows, the bare name `Antigravity` in Radar elsewhere).

[`title.py`](title.py) fills that gap. Antigravity runs it on every agent-state change with
its status-line JSON on stdin and uses what it prints as the terminal title. The script
reads the conversation's own title from
`~/.gemini/antigravity-cli/conversation_summaries.db` by `conversation_id`, and prints the
workspace folder name until Antigravity has named the conversation (or if anything fails),
so it never errors.

## Install

`agy` is a client of the portable AI installer, alongside Claude, Codex, Grok and OpenCode:

```powershell
./ai/Install-AIConfig.ps1 -Install -Clients agy      # Windows (PowerShell 7)
```

```bash
bash ./ai/install.sh --install --clients agy         # macOS / Linux
```

It copies `title.py` to `~/.gemini/antigravity-cli/` and merges a `title` block into that
folder's `settings.json`, keeping every other setting, with a private backup of anything it
changes. Omit `--install` / `-Install` to render into `ai/generated` without touching the
live config. A default run (no `-Clients`) includes `agy`.

Then, once per machine, run **`/title on`** inside Antigravity (`/title off` disables it;
plain `/title` toggles). Restart any `agy` sessions that were already open: they read their
settings at startup.

## Notes

Verified against Antigravity CLI 1.3.3 on Windows and macOS:

- The command path must be **unquoted**: quotes reach the process literally and break it.
  The installer refuses a home directory containing whitespace for that reason.
- The command uses `python` on Windows and `python3` elsewhere, so one of them must be on
  `PATH` for the shell Antigravity runs (uv's Python is enough).
- After 30 consecutive failures Antigravity disables the runner for that session. If titles
  stop, look for `statusline:` lines in `~/.gemini/antigravity-cli/log/cli-*.log`.
- The payload has no conversation title, hence the database lookup. The database is in WAL
  mode, so the script reads a temporary copy of it.
- A brand-new conversation shows the folder name until its first message is processed and a
  title is generated.
- Antigravity adds `"enabled": true` to the `title` block when `/title on` runs; re-running
  the installer keeps it.

Docs: <https://www.antigravity.google/docs/cli/title>,
<https://antigravity.google/docs/cli/commands/title>,
<https://www.antigravity.google/docs/cli/statusline>.
