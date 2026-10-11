#!/usr/bin/env python3
"""Import an allowlisted snapshot of local preferences; never copy auth/session state."""
from __future__ import annotations

import argparse
import datetime as dt
import json
from pathlib import Path
import re
import shutil
import tomllib

from setup import ROOT, REPO, atomic_write, read_json, toml_dumps


def pick(source, names):
    return {name: source[name] for name in names if name in source}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--home", type=Path, default=Path.home())
    args = parser.parse_args()
    home = args.home
    claude = read_json(home / ".claude/settings.json")
    codex = tomllib.loads((home / ".codex/config.toml").read_text(encoding="utf-8-sig"))
    grok = tomllib.loads((home / ".grok/config.toml").read_text(encoding="utf-8-sig"))
    opencode = read_json(home / ".config/opencode/opencode.json")

    claude_preferences = pick(claude, (
        "$schema", "cleanupPeriodDays", "model", "effortLevel", "modelSettings",
        "autoCompactWindow", "tui", "theme", "editorMode", "permissions",
        "skipDangerousModePermissionPrompt", "subagentPromptCacheTtl",
    ))
    # Only known, noncredential environment preferences are imported.
    claude_preferences["env"] = pick(claude.get("env", {}), (
        "CLAUDE_CODE_SUBAGENT_MODEL", "CLAUDE_CODE_SUBAGENT_MODEL_FORCE",
        "CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH", "CLAUDE_CODE_MAX_CONCURRENT_SUBAGENTS",
        "CLAUDE_CODE_FORK_SUBAGENT", "CLAUDE_CODE_ENABLE_PROMPT_SUGGESTION",
        "CLAUDE_CODE_DISABLE_TERMINAL_TITLE", "CLAUDE_CODE_GOAL_CHECKIN_MINUTES",
        "BASH_MAX_OUTPUT_LENGTH", "MAX_MCP_OUTPUT_TOKENS",
    ))
    claude_preferences["statusLine"] = pick(claude.get("statusLine", {}), ("type", "padding", "refreshInterval"))
    claude_preferences["statusLine"]["command"] = 'node "__HOME__/.claude/statusline.js"'
    atomic_write(ROOT / "config/claude/settings.json", json.dumps(claude_preferences, indent=2) + "\n")

    codex_preferences = pick(codex, (
        "model", "model_reasoning_effort", "plan_mode_reasoning_effort",
        "service_tier", "approvals_reviewer", "features", "desktop",
    ))
    codex_preferences["tui"] = pick(codex.get("tui", {}), ("status_line",))
    atomic_write(ROOT / "config/codex/config.toml", toml_dumps(codex_preferences))
    # Windows settings must not be applied to macOS/Linux.
    atomic_write(ROOT / "config/codex/windows.toml", toml_dumps({"windows": pick(codex.get("windows", {}), ("sandbox",))}))

    grok_preferences = {"ui": pick(grok.get("ui", {}), (
        "max_thoughts_width", "fork_secondary_model", "yolo", "compact_mode",
        "permission_mode", "theme",
    )), "models": pick(grok.get("models", {}), ("default", "default_reasoning_effort"))}
    grok_preferences["ui"]["status_line"] = pick(grok.get("ui", {}).get("status_line", {}), ("type", "refresh_interval"))
    grok_preferences["ui"]["status_line"]["command"] = 'node "__HOME__/.grok/statusline.js"'
    # The installer substitutes a native .cmd launcher on Windows. This snapshot
    # remains the POSIX command form for macOS/Linux.
    atomic_write(ROOT / "config/grok/config.toml", toml_dumps(grok_preferences))

    # Preserve OpenCode preferences, with explicit handling of the observed MCP credentials.
    opencode.pop("shell", None)
    opencode["mcp"] = {
        "context7": {
            "type": "remote", "url": "https://mcp.context7.com/mcp", "enabled": True,
            "headers": {"CONTEXT7_API_KEY": "{env:CONTEXT7_API_KEY}"},
        },
        "github": {
            "type": "remote", "url": "https://api.githubcopilot.com/mcp/", "enabled": False,
            "oauth": False, "headers": {"Authorization": "Bearer {env:GITHUB_PERSONAL_ACCESS_TOKEN}"},
        },
    }
    # Refuse future unhandled credentials instead of accidentally exporting them.
    def inspect(value):
        if isinstance(value, dict):
            for key, item in value.items():
                if re.fullmatch(r"(?i)(api_?key|token|secret|password|authorization|client_?secret)", key):
                    if isinstance(item, str) and item and "{env:" not in item:
                        raise ValueError("An unhandled literal credential needs a named environment reference")
                inspect(item)
        elif isinstance(value, list):
            for item in value:
                inspect(item)
    inspect(opencode)
    atomic_write(ROOT / "opencode/config/opencode.json", json.dumps(opencode, indent=2) + "\n")

    themes = home / ".config/opencode/themes"
    if themes.exists():
        for source in themes.glob("*.json"):
            theme = read_json(source)
            if set(theme) - {"$schema", "defs", "theme"}:
                raise ValueError("Unexpected custom theme fields; review before importing")
            atomic_write(ROOT / "opencode/themes" / source.name, json.dumps(theme, indent=2) + "\n")

    for client in ("claude", "grok"):
        source = home / ("." + client) / "statusline.js"
        destination = ROOT / "config" / client / "statusline.js"
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, destination)

    inventory = {
        "captured": dt.date.today().isoformat(),
        "claudeUserMcpServers": sorted(read_json(home / ".claude.json").get("mcpServers", {})),
        "codexMcpServers": sorted(codex.get("mcp_servers", {})),
        "codexEnabledPlugins": sorted(name for name, config in codex.get("plugins", {}).items() if config.get("enabled")),
        "grokMcpServers": sorted(grok.get("mcp_servers", {})),
        "grokEnabledPlugins": grok.get("plugins", {}).get("enabled", []),
        "opencodeMcpServers": sorted(read_json(home / ".config/opencode/opencode.json").get("mcp", {})),
    }
    atomic_write(ROOT / "inventory.json", json.dumps(inventory, indent=2) + "\n")
    print("Imported allowlisted preferences, status-line scripts and MCP/plugin names. No auth files copied.")


if __name__ == "__main__":
    main()
