# Dev / agent benchmarks

Measures how fast a machine (or a disk location on it) is at the work CLI coding agents do all day:
spawning processes, searching, reading and editing files, running `git`, and an optional end-to-end
`claude -p` run. Use it to compare Windows vs macOS vs Linux, or one folder/drive against another
on the same machine (for example `C:` vs a Dev Drive, or a native folder vs a synced folder).

`bench.py` is a single Python file with no dependencies. It works the same on Windows, macOS and Linux.

## Requirements

| Need | Notes |
|---|---|
| Python 3.9+ | `python3 --version`. On Windows, `py -3` or `uv run` also work. |
| `git` | Needed for the spawn and git-status tests. Skipped if missing. |
| `rg` (ripgrep) | Optional. Used for search and glob when present, with a Python fallback. Same machine = same tool, so compare like with like. |
| `claude` CLI | Only for the `claude` subcommand. It must be logged in. |
| A folder of repos | Any folder whose immediate children are git repos (or a single repo). |

## Run it

```sh
cd benchmarks

# 1. Micro-benchmark (free, about a minute). Repeat --root to compare locations.
python3 bench.py micro --root ~/code/astra --json results/mac-ssd.json
python bench.py micro --root C:\Code\Astra --root D:\Astra --json results/win.json

# 2. Claude Code end to end (billed, about $0.04 to $0.15 per run)
python3 bench.py claude --root ~/code/astra --runs 3 --json results/mac-claude.json

# 3. Compare machines (any mix of result files)
python3 bench.py compare results/mac-ssd.json results/win.json
```

Each `--root` is measured separately, so you can compare in one run. Use the **same repos copied to
each location**, so the work is identical. A copy with `.venv` and `node_modules` folders will differ
from one without, so copy them the same way everywhere.

### Options

| Flag | Subcommand | Default | Meaning |
|---|---|---|---|
| `--root PATH` | micro, claude | required | Repo folder to test. Repeatable. |
| `--runs N` | micro, claude | 3 | Timed runs per measurement. Micro adds one discarded warm-up. |
| `--files N` | micro | 2000 | Files created and deleted in the small-file test. |
| `--prompt TEXT` | claude | built-in | Prompt for `claude -p`. Keep it read-only. |
| `--json FILE` | micro, claude | none | Save results so `compare` can merge them. Create the folder first. |

## What it measures

**Process spawn** (`100 x git --version`, `python startup`)
The cost of launching a child process. Agents spawn `git`, `rg` and shells constantly, so this often
dominates. Typical: Linux/macOS about 1 to 5 ms per spawn. Windows with endpoint security (for example
CrowdStrike, Defender real-time) is often 25 to 100 ms per spawn, even though the disk is fast.

**File / search / git ops** (per `--root`)

| Test | What it stresses |
|---|---|
| search: files containing 'import' | Directory walk plus reading many files (`rg` or Python) |
| glob `**/*.py` | Directory walk and metadata |
| git status xN repos | N process spawns plus index reads. Shows spawn cost clearly. |
| read 300 files | Read throughput for small files |
| edit 100 files in place | Create, append and close, then delete |
| create+delete 2000 files | File-creation cost. Filesystem and antivirus scanning dominate. |

**claude -p** (billed)
Runs the same read-only prompt in each `--root` and reports median seconds:
`total` (from Claude's own timer), `api` (time spent waiting on the model) and
`local` = total - api. **`local` is the number the machine can influence.** `api` and `wall`
vary by several seconds between runs because of the model and network. Treat differences under
10 to 15% as noise, and use `--runs 3` or more. `cost` is the sum over the runs.

## Reading the results

- Compare `local`, not `total`, when judging a machine.
- If `git status xN` is slow but `read 300 files` is fast, the bottleneck is process creation, not the
  disk. Moving to a faster drive will not fix it. Ask IT for a security-software exclusion for the repo
  folder and for `git`, `rg`, `uv` and `claude`.
- If `create+delete` is slow but `read` is fast, look at antivirus scanning or a sync client on the folder.
- Compare like with like: same repos, same `rg`/`git` versions, plugged in, no background builds.
  Run the micro test twice. The first run warms caches.

## Windows and WSL

`bench.py` runs natively inside whichever OS launches it. To compare Windows against WSL on the same
machine, run it once in PowerShell and once inside the WSL shell (with its own Python and repos on the
ext4 filesystem, not `/mnt/c`), then `compare` the two JSON files.

`windows/` contains two PowerShell 7 scripts that drive both sides from Windows in a single run:
`Test-AgentPerf.ps1` (spawn cost, agent-style ops, `claude -p`, optional Copilot CLI wall-clock, Git Bash
vs pwsh) and `Test-DevPerf.ps1` (git, grep, file walk, small files and optional `uv sync`). They need
`wsl.exe` and `pwsh`, so use `bench.py` on any machine without WSL.

```powershell
pwsh ./windows/Test-AgentPerf.ps1 -Mode Micro,Claude -WindowsRoot D:\Astra -WslRoot '~/astra' -Runs 3 -GitBash
```

## Notes

- The tests create and delete scratch files named `.agentperf-<pid>` inside each `--root`, and nothing else is
  written. An interrupted run may leave one behind, so it is safe to delete.
- `claude` runs allow only `Glob,Grep,Read,Bash` and the prompt is read-only, but it still bills tokens.
- Results include the hostname and OS in the JSON. Remove them before sharing the files outside your org.
