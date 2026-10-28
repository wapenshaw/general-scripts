#!/usr/bin/env python3
"""Antigravity CLI title script: print the conversation's own title.

Antigravity runs this on every agent-state change, with its status-line JSON on
stdin, and sets the terminal title to whatever is printed. The payload carries
no conversation title, so it is read from conversation_summaries.db by
conversation_id. Until Antigravity has named the conversation (or if anything
fails) the workspace folder name is printed, so the script never errors out.
"""
import json
import re
import shutil
import sqlite3
import sys
import tempfile
from pathlib import Path

HOME = Path.home() / ".gemini" / "antigravity-cli"
DB = HOME / "conversation_summaries.db"
MAX_LEN = 80


def payload():
    try:
        data = json.load(sys.stdin)
    except (ValueError, OSError):
        return {}
    return data if isinstance(data, dict) else {}


def folder(data):
    where = data.get("cwd") or (data.get("workspace") or {}).get("current_dir") or ""
    return Path(str(where).rstrip("/\\")).name


def conversation_title(conversation_id):
    # The db is in WAL mode; read a copy so the live files are never opened.
    with tempfile.TemporaryDirectory() as tmp:
        for suffix in ("", "-wal", "-shm"):
            src = DB.with_name(DB.name + suffix)
            if src.exists():
                shutil.copy2(src, Path(tmp) / src.name)
        con = sqlite3.connect(Path(tmp) / DB.name)
        try:
            row = con.execute(
                "SELECT title FROM conversation_summaries WHERE conversation_id = ?",
                (conversation_id,),
            ).fetchone()
        finally:
            con.close()
    return (row[0] or "") if row else ""


def tidy(text):
    text = re.sub(r"[\x00-\x1f\x7f]+", " ", text).strip()
    return text if len(text) <= MAX_LEN else text[: MAX_LEN - 1].rstrip() + "…"


def main():
    data = payload()
    title = ""
    conversation_id = data.get("conversation_id") or data.get("session_id")
    if conversation_id:
        try:
            title = conversation_title(conversation_id)
        except (OSError, sqlite3.Error):
            title = ""
    sys.stdout.reconfigure(encoding="utf-8")
    print(tidy(title) or tidy(folder(data)) or "Antigravity")


if __name__ == "__main__":
    main()
