from __future__ import annotations

import argparse
import json
import os
import sys
from importlib.resources import files
from pathlib import Path

from .core import KnowledgeBase, SCOPES


CONFIG_NAME = "knowledge.toml"


def find_config(explicit: str | None, start: Path | None = None) -> Path:
    """--config, then $REPO_KNOWLEDGE_CONFIG, then knowledge.toml in the working directory
    or the nearest parent. Raises ValueError with setup guidance when none is found."""
    if explicit:
        return Path(explicit)
    if env := os.environ.get("REPO_KNOWLEDGE_CONFIG"):
        return Path(env)
    start = (start or Path.cwd()).resolve()
    for folder in (start, *start.parents):
        if (folder / CONFIG_NAME).is_file():
            return folder / CONFIG_NAME
    raise ValueError(f"No {CONFIG_NAME} in {start} or its parents. Add one at the project root "
                     "(see `repo-knowledge example-config`), set REPO_KNOWLEDGE_CONFIG, or pass --config.")


def main() -> None:
    parser = argparse.ArgumentParser(description="Project-scoped knowledge MCP and CLI")
    parser.add_argument("--config", help=f"Project TOML file (default: $REPO_KNOWLEDGE_CONFIG, else the nearest {CONFIG_NAME} upward from the working directory)")
    parser.add_argument("--exclude", action="append", default=[], metavar="GLOB",
                        help="Extra root-relative glob to leave out (repeatable), e.g. for evaluation runs")
    commands = parser.add_subparsers(dest="command", required=True)
    commands.add_parser("serve", help="Run the read-only MCP server over stdio")
    commands.add_parser("status")
    commands.add_parser("manifest", help="Write a fresh full JSON manifest to stdout")
    commands.add_parser("skill", help="Print the portable companion SKILL.md")
    commands.add_parser("example-config", help=f"Print an example {CONFIG_NAME}")
    records = commands.add_parser("records")
    records.add_argument("--scope", choices=SCOPES, default="not_superseded")
    records.add_argument("--offset", type=int, default=0)
    records.add_argument("--limit", type=int, default=50)
    records.add_argument("--record-type")
    search = commands.add_parser("search")
    search.add_argument("query")
    search.add_argument("--scope", choices=SCOPES, default="all")
    search.add_argument("--limit", type=int, default=10)
    search.add_argument("--record-type")
    read = commands.add_parser("read")
    read.add_argument("path")
    read.add_argument("--start-line", type=int, default=1)
    read.add_argument("--max-lines", type=int, default=120)
    args = parser.parse_args()
    if args.command == "skill":
        print(files("repo_knowledge").joinpath("skills/repo-knowledge/SKILL.md").read_text())
        return
    if args.command == "example-config":
        print(files("repo_knowledge").joinpath("example.toml").read_text())
        return
    if args.command == "serve":
        # Start even without a config, so one user-level server entry works in every
        # repository; tools explain how to add knowledge.toml until one exists.
        from .server import create_server
        cache: dict = {}

        def get_kb() -> KnowledgeBase:
            if "kb" not in cache:
                cache["kb"] = KnowledgeBase(find_config(args.config), args.exclude)
            return cache["kb"]

        create_server(get_kb).run(transport="stdio")
        return
    try:
        kb = KnowledgeBase(find_config(args.config), args.exclude)
        if args.command == "manifest":
            result, _ = kb.snapshot()
        elif args.command == "search":
            result = kb.search(args.query, args.scope, args.limit, args.record_type)
        elif args.command == "read":
            result = kb.read(args.path, args.start_line, args.max_lines)
        elif args.command == "records":
            result = kb.records(args.scope, args.record_type, args.offset, args.limit)
        else:
            result = kb.status()
        print(json.dumps(result, indent=2, ensure_ascii=False))
    except (OSError, ValueError) as exc:
        print(f"repo-knowledge: {exc}", file=sys.stderr)
        raise SystemExit(2) from exc


if __name__ == "__main__":
    main()
