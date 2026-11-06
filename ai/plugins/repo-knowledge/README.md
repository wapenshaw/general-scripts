# repo-knowledge

A read-only MCP server, CLI and agent skill for finding a project's own records with explicit status and provenance: what was decided, what was posted or sent, what is still a draft, and what has been superseded. Works with any agent that speaks MCP or reads Agent Skills (Claude Code, Codex, GitHub Copilot, OpenCode). Keyword search only: no embedding model, vector database or Docker.

Each project opts in with a `knowledge.toml` at its root that lists which files to read and what kind of record each is. Projects keep their own config; nothing project-specific lives here.

## Install (user level, once per machine)

```sh
~/Code/Scripts/ai/plugins/repo-knowledge/install.sh
```

The installer is idempotent and only touches clients that are installed:

| Piece | Where | Used by |
|---|---|---|
| CLI `repo-knowledge` | `uv tool install --editable` → `~/.local/bin` | everything below; edits here take effect without reinstalling |
| Skill | `~/.agents/skills/repo-knowledge` → `src/repo_knowledge/skills/repo-knowledge` | Codex, Copilot, OpenCode |
| Skill link | `~/.claude/skills/repo-knowledge` → `../../.agents/skills/repo-knowledge` | Claude Code (Copilot also reads it) |
| MCP server | `claude mcp add --scope user`, `codex mcp add`, `copilot mcp add` (`repo-knowledge serve`) | each installed client |

Config files a client CLI edits are backed up first to `~/.local/state/ai-config-backups/`. Uninstall: `claude mcp remove --scope user repo-knowledge`, `codex mcp remove repo-knowledge`, remove the two skill links, `uv tool uninstall repo-knowledge-mcp`. The server entry is also in `ai/mcp/servers.json` (disabled by default) so `setup.py --enable repo-knowledge` can render it once the CLI is installed.

## Enable it in a project

```sh
cd <project root>
repo-knowledge example-config > knowledge.toml   # then edit name, sources and record types
repo-knowledge status                            # check counts and read errors
```

The server and CLI find the config in this order: `--config`, `$REPO_KNOWLEDGE_CONFIG`, then the nearest `knowledge.toml` from the working directory upward. MCP clients start the server in the project directory, so one user-level entry serves every project. In a project without `knowledge.toml` the tools return a message explaining how to add one instead of failing to start.

Config keys: `name`, `root` (relative to the config file), `exclude` (globs), `max_file_bytes`, `[[sources]]` with `pattern` and `record_type` (first matching source wins; put specific patterns first), and optional `[snapshot_check]` with `snapshot_type` and `update_types` (warn when a snapshot, such as an issue export named after its key, is older than a later posted update naming the same key).

## CLI

```sh
repo-knowledge status
repo-knowledge search 'PROJ-123 close-out' [--scope all|not_superseded|pending] [--record-type T] [--limit N]
repo-knowledge records --scope pending [--record-type T]
repo-knowledge read path/to/file.md --start-line 40
repo-knowledge manifest            # full JSON to stdout
repo-knowledge skill               # print SKILL.md
repo-knowledge --exclude 'eval/**' search ...   # extra exclusions, e.g. for evaluation runs
```

`serve` speaks MCP over stdio; other commands print JSON.

## Tools

| Tool | Purpose |
|---|---|
| `kb_status` | Fresh counts, metadata coverage and files that could not be read |
| `kb_records` | Paginated metadata, filtered by scope and optional record type |
| `kb_search` | Literal keyword search: records with every term first, then partial matches with `missing_terms`; one result per distinct source record |
| `kb_read` | Current text with path, line window, hash and status |

Search defaults to `all`, keeping history discoverable. `not_superseded` excludes only whole-record supersession and retains partial records. `pending` selects draft, not-posted and partially posted records, excluding whole-record supersession. Pending records are not a replacement for the project's task system.

Search ranks records by how many query terms they contain, then by bounded term frequency plus path matches. It is a simple keyword baseline, not BM25 or semantic search. Excerpts are the three lines matching the most terms. Use synonyms when a topic search misses. Inline supersession markers and line numbers help inspect replaced passages; the tool does not automatically resolve conflicting claims.

Every request rescans the allowlist and hashes current content. File additions, edits and deletions are reflected without a cached manifest. A request is a best-effort filesystem snapshot, not a transaction across all files. Compare source hashes between search and read if concurrent edits matter. This approach favors simplicity for small documentation repositories; measure performance before scaling it.

### Supported metadata

Opening metadata can use plain `Key: value` or Markdown `- Key: value` lines. Parsing stops at the first level-two heading or code fence, and inspects at most 40 opening lines.

- `Status: DRAFT | SENT | RECEIVED | NOT POSTED | PARTIALLY POSTED | POSTED`, retaining the original detail.
- Legacy `POSTED in part`, `HELD`, and leading `SUPERSEDED` statements are read without rewriting source files.
- `Superseded: whole` plus `Superseded-by: <reference or unknown>`.
- Inline `(superseded YYYY-MM-DD: <reference>)` marks partial supersession and records its line number.
- `Date:` or `Recorded:` accepts ISO dates or dates such as `6 November 2026`; otherwise an ISO filename prefix supplies the record date. Missing values remain unknown.
- For `record_type = "ticket_snapshot"`, issue status is returned as `ticket_status`, separately from `workflow_status`. `Updated:` is returned as `source_updated`; it does not prove when the snapshot was fetched.

The returned manifest includes path, type, workflow status and detail, record date, supersession scope and target, source hash, inline marker locations and parser warnings. Missing supersession information does not establish authority.

### Source boundaries and generated output

Only allowlisted UTF-8 `.md` and `.txt` files and `.xlsx` workbooks are read. Workbooks are converted in memory, read-only and with the standard library, to one line per row: `[Sheet] row N | Header: value | ...`, with ISO dates and struck-through text kept as `~~text~~` (a strike often means received or withdrawn). Cite the sheet and row, not the line number. Symlinks, files outside the root, common generated directories, and files over the configured size limit are excluded or reported as errors. All tools are read-only. Configuration contains no hooks or commands to execute. Original documents and existing workbook/task sources remain authoritative.

`manifest` prints fresh JSON to stdout. If a saved copy is needed, write it to an ignored cache in the project and regenerate it before use; the server never reads a saved copy, so it cannot serve an outdated one.

## Companion skill

`src/repo_knowledge/skills/repo-knowledge/SKILL.md` is the single copy; the installer links it, and `repo-knowledge skill` prints it. The skill explains how to read status, supersession and authority; filtering logic stays in code so every agent gets the same behaviour. Projects' own rules for tasks, issue updates and document edits still apply.

## Development

```sh
cd ~/Code/Scripts/ai/plugins/repo-knowledge
uv run --with pytest pytest -q
uv build --out-dir dist   # wheel includes the skill and example config
```

Tests cover status parsing, partial completion, whole and partial supersession, stale-snapshot warnings, partial keyword matches, workbook extraction, config discovery, project boundaries and real MCP stdio calls (including a server started with no config). The server uses the [official Python MCP SDK](https://github.com/modelcontextprotocol/python-sdk), pinned in `pyproject.toml`.

Not implemented: Word, PowerPoint and PDF ingestion; task-store adapters; semantic retrieval; HTTP hosting. A semantic backend (for example QMD) can sit behind the same tools if a project's retrieval baseline shows keyword search missing too often.
