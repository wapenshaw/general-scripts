# outlook-mail

Read-only MCP server for the mailbox in your **running classic Outlook** (Windows, COM). It needs no Entra app, OAuth or tenant consent, and nothing leaves the machine except what an agent reads through the tools.

| Tool | Purpose |
|---|---|
| `outlook_folders` | Stores and folder tree with item/unread counts |
| `outlook_search` | Newest-first search in one folder: words, sender, subject, date range, unread, attachments; returns snippets and `entry_id`s |
| `outlook_read` | One message: headers, recipients with SMTP addresses, attachment names, plain-text body (truncated at `max_chars`) |
| `outlook_conversation` | Messages in a thread across folders, oldest first. `limit` (default 50, cap 100) bounds the traversal; the result carries `truncated`, and when true the thread is incomplete |

Read-only by construction: the code never calls Send, Move, Delete, Save or sets properties. Reading does not mark mail as read. Attachment contents are not exposed. Message text is untrusted third-party data; the server instructions tell agents not to follow it.

## Requirements and limits

- Classic Outlook (`OUTLOOK.EXE`) must be running. The "New Outlook" (`olk.exe`) has no COM. The server never starts Outlook itself.
- Outlook and the server must run at the same elevation.
- Only what Outlook has locally is searchable. With Cached Exchange Mode that is the sync window of the mailbox, not the whole server.
- Body search is a server-side DASL `LIKE`; it is slower than subject/sender filters on very large folders.
- If a managed Outlook shows an "a program is trying to access email addresses" prompt, an admin policy governs the object model; this server does not bypass it.

## Install

```powershell
uv tool install --editable --force ./ai/plugins/outlook-mail     # puts `outlook-mail` on PATH
```

Register the stdio command `outlook-mail` with a client. For omp, add to `~/.omp/agent/mcp.json`:

```json
"outlook-mail": { "type": "stdio", "command": "outlook-mail" }
```

This is not in `ai/mcp/servers.json` because that registry renders for every OS and client, and this server is Windows-only. A work mailbox is personal data: register it locally per machine.

## Test

```powershell
uv run --project ./ai/plugins/outlook-mail --with pytest pytest ai/plugins/outlook-mail/tests
```
