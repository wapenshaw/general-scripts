#!/usr/bin/env python3
"""Cross-platform dev/agent benchmark (Windows, macOS, Linux). Python 3.9+, stdlib only.

Subcommands:
  micro    process-spawn cost + the file/search/git operations coding agents issue constantly
  claude   runs `claude -p` on a read-only prompt; reports total / API / local time
  compare  merges result JSON files from several machines/locations into one table

See INSTRUCTIONS.md.
"""
from __future__ import annotations

import argparse
import json
import os
import platform
import shutil
import statistics
import subprocess
import sys
import time
from pathlib import Path

CLAUDE_PROMPT = (
    "Use Grep to count the python files that contain the word import across this directory tree, "
    "then run `git status --short` and `git log --oneline -n 20` with Bash inside the first git "
    "repository you find. Reply with one line: the count of python files."
)


def median(values):
    return statistics.median(values) if values else float("nan")


def timed(fn, runs, warmup=1):
    """Median seconds of fn() over `runs` runs after `warmup` discarded runs."""
    for _ in range(warmup):
        fn()
    samples = []
    for _ in range(runs):
        t0 = time.perf_counter()
        fn()
        samples.append(time.perf_counter() - t0)
    return median(samples)


def run(cmd, cwd=None):
    return subprocess.run(cmd, cwd=cwd, stdin=subprocess.DEVNULL, capture_output=True, text=True)


def host_info():
    return {
        "host": platform.node(),
        "os": f"{platform.system()} {platform.release()}",
        "python": platform.python_version(),
        "wsl": "microsoft" in platform.release().lower(),
        "git": run(["git", "--version"]).stdout.strip() if shutil.which("git") else "missing",
    }


def label_for(root: Path) -> str:
    return f"{platform.system().lower()}:{root}"


def find_repos(root: Path, limit=30):
    if (root / ".git").exists():
        return [root]
    return sorted(p for p in root.iterdir() if (p / ".git").exists())[:limit]


def py_files(root: Path):
    if shutil.which("rg"):
        return run(["rg", "--files", "--glob", "*.py", str(root)]).stdout.splitlines()
    skip = {".git", ".venv", "node_modules", "__pycache__"}
    found = []
    for dp, dn, fn in os.walk(root):
        dn[:] = [d for d in dn if d not in skip]
        found += [os.path.join(dp, f) for f in fn if f.endswith(".py")]
    return found


def count_import(root: Path):
    if shutil.which("rg"):
        return len(run(["rg", "-l", "--type", "py", "import", str(root)]).stdout.splitlines())
    n = 0
    for f in py_files(root):
        try:
            if "import" in Path(f).read_text(errors="ignore"):
                n += 1
        except OSError:
            pass
    return n


def micro(args, results):
    git = shutil.which("git")
    if git:
        results["spawn"] = {
            "100 x git --version": timed(lambda: [run([git, "--version"]) for _ in range(100)], 2),
            "python startup": timed(lambda: run([sys.executable, "-c", "pass"]), 5),
        }
    for root_s in args.root:
        root = Path(root_s).expanduser().resolve()
        if not root.is_dir():
            print(f"skip {root}: not a directory", file=sys.stderr)
            continue
        label = label_for(root)
        print(f"== {label}", file=sys.stderr)
        repos = find_repos(root)
        files = py_files(root)[:300]
        scratch = root / f".agentperf-{os.getpid()}"
        ops = {}
        ops["search: files containing 'import'"] = timed(lambda: count_import(root), args.runs)
        ops["glob **/*.py"] = timed(lambda: py_files(root), args.runs)
        if git and repos:
            ops[f"git status x{len(repos)} repos"] = timed(
                lambda: [run([git, "-C", str(r), "status", "--porcelain"]) for r in repos], args.runs
            )
        ops[f"read {len(files)} files"] = timed(lambda: [Path(f).read_bytes() for f in files], args.runs)

        def edit100():
            scratch.mkdir(exist_ok=True)
            try:
                for i in range(100):
                    (scratch / f"f{i}.txt").write_text("a")
                for i in range(100):
                    with open(scratch / f"f{i}.txt", "a") as fh:
                        fh.write("b")
            finally:
                shutil.rmtree(scratch, ignore_errors=True)

        def create_many():
            scratch.mkdir(exist_ok=True)
            try:
                for i in range(args.files):
                    (scratch / f"f{i}.txt").write_text("x")
            finally:
                shutil.rmtree(scratch, ignore_errors=True)

        ops["edit 100 files in place"] = timed(edit100, args.runs)
        ops[f"create+delete {args.files} files"] = timed(create_many, max(1, args.runs - 1))
        results.setdefault("ops", {})[label] = ops


def claude(args, results):
    exe = shutil.which("claude")
    if not exe:
        sys.exit("claude CLI not found on PATH")
    allowed = "Glob,Grep,Read,Bash"
    for root_s in args.root:
        root = Path(root_s).expanduser().resolve()
        label = label_for(root)
        print(f"== claude -p in {label} ({args.runs} billed runs)", file=sys.stderr)
        rows = []
        for _ in range(args.runs):
            t0 = time.perf_counter()
            p = run([exe, "-p", args.prompt, "--output-format", "json", "--allowedTools", allowed], cwd=root)
            wall = time.perf_counter() - t0
            try:
                o = json.loads(p.stdout)
                if isinstance(o, list):  # some builds emit an array of events
                    o = [e for e in o if e.get("type") == "result"][-1]
                rows.append({
                    "wall": wall,
                    "total": o["duration_ms"] / 1000,
                    "api": o["duration_api_ms"] / 1000,
                    "local": (o["duration_ms"] - o["duration_api_ms"]) / 1000,
                    "turns": o.get("num_turns", 0),
                    "cost": float(o.get("total_cost_usd", 0)),
                })
            except (ValueError, IndexError, KeyError):
                print(f"  unparseable output (exit {p.returncode}): {p.stderr[:200]}", file=sys.stderr)
        if rows:
            results.setdefault("claude", {})[label] = {
                **{k: median([r[k] for r in rows]) for k in ("wall", "total", "api", "local", "turns")},
                "cost": sum(r["cost"] for r in rows),
            }


def table(headers, rows):
    widths = [max(len(str(x)) for x in col) for col in zip(headers, *rows)]
    for line in [headers, ["-" * w for w in widths], *rows]:
        print("  ".join(str(c).ljust(w) for c, w in zip(line, widths)))


def fmt(v):
    return "" if v is None else f"{v:.3f}" if isinstance(v, float) else str(v)


def show(results_list):
    """results_list: [(name, result dict)]. Prints spawn, ops and claude tables."""
    spawn = {name: r["spawn"] for name, r in results_list if r.get("spawn")}
    if spawn:
        tests = list(dict.fromkeys(t for d in spawn.values() for t in d))
        print("\nProcess spawn (s)")
        table(["test", *spawn], [[t, *[fmt(spawn[n].get(t)) for n in spawn]] for t in tests])
    ops = {}
    for name, r in results_list:
        for label, tests in r.get("ops", {}).items():
            ops[f"{name} {label}" if len(results_list) > 1 else label] = tests
    if ops:
        tests = list(dict.fromkeys(t for d in ops.values() for t in d))
        print("\nFile / search / git ops (s, median)")
        table(["test", *ops], [[t, *[fmt(ops[n].get(t)) for n in ops]] for t in tests])
    cl = {}
    for name, r in results_list:
        for label, v in r.get("claude", {}).items():
            cl[f"{name} {label}" if len(results_list) > 1 else label] = v
    if cl:
        print("\nclaude -p (median s; cost = sum of runs)")
        keys = ("wall", "total", "api", "local", "turns", "cost")
        table(["target", *keys], [[n, *[fmt(round(v[k], 2)) for k in keys]] for n, v in cl.items()])


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    for name in ("micro", "claude"):
        p = sub.add_parser(name)
        p.add_argument("--root", action="append", required=True, help="folder containing repos; repeat per location")
        p.add_argument("--runs", type=int, default=3)
        p.add_argument("--json", help="write results to this file for `compare`")
        if name == "micro":
            p.add_argument("--files", type=int, default=2000)
        else:
            p.add_argument("--prompt", default=CLAUDE_PROMPT)
    c = sub.add_parser("compare")
    c.add_argument("files", nargs="+")
    args = ap.parse_args()

    if args.cmd == "compare":
        show([(Path(f).stem, json.loads(Path(f).read_text())) for f in args.files])
        return
    results = {"info": host_info(), "created": time.strftime("%Y-%m-%d %H:%M:%S")}
    (micro if args.cmd == "micro" else claude)(args, results)
    show([(results["info"]["host"] or "this", results)])
    if args.json:
        Path(args.json).write_text(json.dumps(results, indent=2))
        print(f"\nsaved {args.json}")


if __name__ == "__main__":
    main()
