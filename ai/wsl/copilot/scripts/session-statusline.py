#!/usr/bin/python3
"""Center Copilot's session label within the current terminal pane."""

import json
import os
import subprocess
import sys
import unicodedata


def cell_width(character):
    if unicodedata.combining(character):
        return 0
    return 2 if unicodedata.east_asian_width(character) in ("W", "F") else 1


def centered_label(name, columns):
    name = " ".join(
        "".join(
            character
            for character in name
            if not unicodedata.category(character).startswith("C")
        ).split()
    )
    text = f"Session: {name}"
    if sum(map(cell_width, text)) > columns:
        clipped = ""
        width = 0
        for character in text:
            size = cell_width(character)
            if width + size > max(0, columns - 3):
                break
            clipped += character
            width += size
        text = clipped + "." * min(3, columns)
    padding = max(0, (columns - sum(map(cell_width, text))) // 2)
    # Copilot trims stdout; an ANSI reset preserves the leading alignment spaces.
    return "\033[0m" + " " * padding + text


def terminal_columns():
    if os.environ.get("HERDR_ENV") == "1":
        binary = os.environ.get("HERDR_BIN_PATH", "/home/heaton/.local/bin/herdr")
        result = subprocess.run(
            [binary, "pane", "layout", "--current"],
            check=True,
            capture_output=True,
            text=True,
            timeout=2,
        )
        layout = json.loads(result.stdout)["result"]["layout"]
        pane = next(
            pane
            for pane in layout["panes"]
            if pane["pane_id"] == os.environ["HERDR_PANE_ID"]
        )
        return pane["rect"]["width"]
    with open("/dev/tty", "rb", buffering=0) as terminal:
        return os.get_terminal_size(terminal.fileno()).columns


def main():
    status = json.load(sys.stdin)
    name = status.get("session_name")
    if name is None or name == "":
        return
    if not isinstance(name, str):
        raise ValueError("session_name must be a string")
    columns = terminal_columns()
    if not isinstance(columns, int) or columns < 1:
        raise ValueError("terminal width must be a positive integer")
    print(centered_label(name, columns))


if __name__ == "__main__":
    main()
