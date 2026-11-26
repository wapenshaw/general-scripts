#!/usr/bin/env python3
# /// script
# requires-python = ">=3.11"
# dependencies = ["ruamel.yaml>=0.18"]
# ///
"""Render or install portable AI preferences and MCP definitions (Python 3.11+)."""
from __future__ import annotations

import argparse
import copy
import datetime as dt
import io
import json
import os
from pathlib import Path
import re
import shlex
import shutil
import sys
import tomllib
from ruamel.yaml import YAML

ROOT = Path(__file__).resolve().parent
REPO = ROOT.parent
CLIENTS = ("claude", "codex", "grok", "opencode")
# Clients with preferences but no MCP definitions rendered by this script.
EXTRA_CLIENTS = ("agy", "omp")


class MissingEnvironmentError(ValueError):
    """Contains only server and variable names, never their values."""


def read_json(path):
    return json.loads(path.read_text(encoding="utf-8-sig"))


def toml_dumps(data):
    """Serialize config data, including quoted keys and arrays of tables."""
    lines = []

    def key(value):
        return value if re.fullmatch(r"[A-Za-z0-9_-]+", value) else json.dumps(value, ensure_ascii=False)

    def scalar(value):
        if isinstance(value, bool):
            return "true" if value else "false"
        if isinstance(value, str):
            return json.dumps(value, ensure_ascii=False)
        if isinstance(value, (dt.datetime, dt.date, dt.time)):
            return value.isoformat()
        if isinstance(value, (int, float)):
            return str(value).lower()
        if isinstance(value, list):
            return "[" + ", ".join(scalar(item) for item in value) + "]"
        if isinstance(value, dict):
            return "{ " + ", ".join(f"{key(k)} = {scalar(v)}" for k, v in value.items()) + " }"
        raise ValueError(f"Unsupported TOML value type: {type(value).__name__}")

    def table(values, parts, header=False, array=False):
        if header:
            name = ".".join(key(part) for part in parts)
            lines.extend(["", f"[[{name}]]" if array else f"[{name}]"])
        for name, value in values.items():
            if not isinstance(value, dict) and not (
                isinstance(value, list) and value and all(isinstance(item, dict) for item in value)
            ):
                lines.append(f"{key(name)} = {scalar(value)}")
        for name, value in values.items():
            if isinstance(value, dict):
                table(value, parts + [name], True)
            elif isinstance(value, list) and value and all(isinstance(item, dict) for item in value):
                for item in value:
                    table(item, parts + [name], True, True)

    table(data, [])
    return "\n".join(lines).strip() + "\n"


def merge(existing, desired):
    result = copy.deepcopy(existing)
    for key, value in desired.items():
        if isinstance(value, dict) and isinstance(result.get(key), dict):
            result[key] = merge(result[key], value)
        else:
            result[key] = copy.deepcopy(value)
    return result


def native_server(client, server, enabled, platform, templates=False):
    if server["transport"] == "stdio":
        command, args = server["command"], list(server.get("args", []))
        if platform == "windows" and command == "npx":
            command, args = "cmd.exe", ["/d", "/c", "npx", *args]
        result = {"command": command, "args": args}
        if client == "claude":
            result["type"] = "stdio"
        elif client == "opencode":
            result = {"type": "local", "command": [command, *args]}
    else:
        result = {"url": server["url"]}
        if client == "claude":
            result["type"] = "http"
        elif client == "opencode":
            result["type"] = "remote"
        header_vars = dict(server.get("optionalHeaderEnv", {}))
        if not templates:
            header_vars = {header: var for header, var in header_vars.items() if os.environ.get(var)}
        if header_vars:
            if client == "codex":
                result["env_http_headers"] = header_vars
            else:
                result["headers"] = {
                    header: "{env:" + var + "}" if client == "opencode" else "${" + var + "}"
                    for header, var in header_vars.items()
                }
        if token_var := server.get("bearerTokenEnv"):
            if client == "codex":
                result["bearer_token_env_var"] = token_var
            else:
                reference = "{env:" + token_var + "}" if client == "opencode" else "${" + token_var + "}"
                result.setdefault("headers", {})["Authorization"] = "Bearer " + reference
            if client == "opencode":
                result["oauth"] = False
    if client != "claude":
        result["enabled"] = enabled
    return result


def render_mcps(registry, platform, enable, disable, templates=False):
    result = {client: {} for client in CLIENTS}
    for name, server in registry.items():
        enabled = (server.get("defaultEnabled", False) or name in enable) and name not in disable
        if enabled and not templates and (token_var := server.get("bearerTokenEnv")) and not os.environ.get(token_var):
            raise MissingEnvironmentError(f"{name} requires environment variable {token_var}; no value is written to config")
        for client in CLIENTS:
            # Claude has no equivalent of enabled=false in its server entries.
            if client == "claude" and not enabled:
                continue
            result[client][name] = native_server(client, server, enabled, platform, templates)
    return result


def yaml_loader():
    # Preference files are YAML 1.2. PyYAML (YAML 1.1) reads keys such as `on` as booleans.
    return YAML(typ="safe", pure=True)


def encode(path, value):
    if path.suffix in (".yml", ".yaml"):
        # Block style, source key order, no line wrapping: the safe dumper
        # otherwise writes leaf maps/lists as wrapped flow style, sorted.
        dumper = yaml_loader()
        dumper.default_flow_style = False
        dumper.sort_base_mapping_type_on_output = False
        dumper.width = 4096
        stream = io.StringIO()
        dumper.dump(value, stream)
        return stream.getvalue()
    return toml_dumps(value) if path.suffix == ".toml" else json.dumps(value, indent=2, ensure_ascii=False) + "\n"


def load_config(path):
    if not path.exists():
        return {}
    if path.suffix == ".toml":
        return tomllib.loads(path.read_text(encoding="utf-8-sig"))
    if path.suffix in (".yml", ".yaml"):
        return yaml_loader().load(path.read_text(encoding="utf-8-sig")) or {}
    return read_json(path)


def omp_settings_path(agent_dir):
    # oh-my-pi reads config.yml first; an existing config.yaml is active only when config.yml is absent.
    canonical, legacy = agent_dir / "config.yml", agent_dir / "config.yaml"
    return legacy if not canonical.exists() and legacy.exists() else canonical


MANAGED_BEGIN = "<!-- BEGIN ai-config: {name} -->"
MANAGED_END = "<!-- END ai-config: {name} -->"


def merge_managed_block(current, block, name):
    """Return `current` with the repo-owned `block` installed between marker comments.

    Everything outside the markers is local and left untouched; edits inside them
    are overwritten. An unmarked file whose whole content already equals the block
    (a hand-copied earlier install) is adopted in place rather than duplicated.
    Otherwise the block is appended after the existing content.
    """
    begin, end = MANAGED_BEGIN.format(name=name), MANAGED_END.format(name=name)
    body = block.strip("\n")
    managed = f"{begin}\n{body}\n{end}\n"
    start = current.find(begin)
    if start != -1:
        stop = current.find(end, start)
        if stop == -1 or current.find(begin, start + 1) != -1:
            raise ValueError(f"unbalanced managed block markers for {name}")
        line_end = current.find("\n", stop)
        return current[:start] + managed + current[len(current) if line_end == -1 else line_end + 1:]
    if not current.strip() or current.strip("\n") == body:
        return managed
    return current.rstrip("\n") + "\n\n" + managed


def find_node():
    found = shutil.which("node")
    if found or os.name != "nt":
        return found
    # Editors/agents can retain an older PATH after runtime setup. Read persisted
    # paths for discovery without replacing the calling process's environment.
    import winreg
    paths = []
    for hive, key in (
        (winreg.HKEY_LOCAL_MACHINE, r"SYSTEM\CurrentControlSet\Control\Session Manager\Environment"),
        (winreg.HKEY_CURRENT_USER, "Environment"),
    ):
        try:
            with winreg.OpenKey(hive, key) as handle:
                paths.append(os.path.expandvars(winreg.QueryValueEx(handle, "Path")[0]))
        except OSError:
            pass
    return shutil.which("node", path=";".join(paths))


def grok_windows_launcher(node):
    # Grok first spawns command as one filename. A native batch file avoids the
    # invalid full-command filename; rust's Windows launcher handles .cmd files.
    return '@echo off\n"' + node.replace("%", "%%") + '" "%~dp0statusline.js"\nexit /b %errorlevel%\n'


def unix_node_launcher(node):
    # An absolute node path recorded at install time breaks when nvm removes that
    # version, so resolve node each time the status line runs.
    fallback = shlex.quote(node)
    return f"""#!/bin/sh
# Generated by ai/setup.py: runs statusline.js with whichever node exists now.
node=$(command -v node 2>/dev/null)
if [ -z "$node" ] && [ -d "$HOME/.nvm/versions/node" ]; then
  want=$(cat "$HOME/.nvm/alias/default" 2>/dev/null)
  for candidate in "$HOME"/.nvm/versions/node/v"${{want#v}}"*/bin/node "$HOME"/.nvm/versions/node/v*/bin/node; do
    if [ -x "$candidate" ]; then node=$candidate; break; fi
  done
fi
if [ -z "$node" ]; then
  for candidate in {fallback} /opt/homebrew/bin/node /usr/local/bin/node; do
    if [ -x "$candidate" ]; then node=$candidate; break; fi
  done
fi
exec "${{node:-node}}" "$(dirname "$0")/statusline.js"
"""


def atomic_write(path, content):
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(path.name + f".tmp-{os.getpid()}")
    try:
        with temporary.open("x", encoding="utf-8", newline="\n") as stream:
            os.chmod(temporary, 0o600)
            stream.write(content)
        os.replace(temporary, path)
    finally:
        temporary.unlink(missing_ok=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--clients", nargs="+", choices=CLIENTS + EXTRA_CLIENTS, default=list(CLIENTS + EXTRA_CLIENTS))
    parser.add_argument("--platform", choices=("windows", "macos", "linux"))
    parser.add_argument("--home", type=Path, help="Override destinations; ignores client home environment overrides")
    parser.add_argument("--output", type=Path, default=ROOT / "generated")
    parser.add_argument("--enable", nargs="*", default=[])
    parser.add_argument("--disable", nargs="*", default=[])
    parser.add_argument("--install", action="store_true", help="Back up and merge into live config; default only renders")
    parser.add_argument("--write-templates", action="store_true", help="Regenerate tracked MCP skeletons, without installing")
    args = parser.parse_args()
    actual_platform = "windows" if os.name == "nt" else "macos" if sys.platform == "darwin" else "linux"
    platform = args.platform or actual_platform
    if args.install and platform != actual_platform:
        parser.error("Install on the target OS; use render mode to preview another platform")
    if args.install and args.write_templates:
        parser.error("--install and --write-templates are separate actions")
    registry = read_json(ROOT / "mcp/servers.json")["servers"]
    unknown = set(args.enable + args.disable) - registry.keys()
    if unknown:
        parser.error("Unknown MCP servers: " + ", ".join(sorted(unknown)))
    mcps = render_mcps(registry, platform, args.enable, args.disable, templates=args.write_templates)
    if args.write_templates:
        # Track both local-process launch forms for Windows and macOS/Linux.
        for target_platform in ("windows", "macos"):
            target_mcps = render_mcps(registry, target_platform, args.enable, args.disable, templates=True)
            for client in CLIENTS:
                section = "mcpServers" if client == "claude" else "mcp" if client == "opencode" else "mcp_servers"
                suffix = ".json" if client in ("claude", "opencode") else ".toml"
                path = ROOT / "mcp/templates" / target_platform / (client + suffix)
                atomic_write(path, encode(path, {section: target_mcps[client]}))
        print("Generated tracked MCP templates for Windows and macOS/Linux. No live config changed.")
        return

    home = (args.home or Path.home()).resolve()
    env_home = lambda key, default: Path(os.environ.get(key, str(default))) if args.home is None else default
    client_roots = {
        "claude": env_home("CLAUDE_CONFIG_DIR", home / ".claude"),
        "codex": env_home("CODEX_HOME", home / ".codex"),
        "grok": env_home("GROK_HOME", home / ".grok"),
        "opencode": env_home("XDG_CONFIG_HOME", home / ".config") / "opencode",
        "agy": home / ".gemini" / "antigravity-cli",
        "omp": env_home("PI_CODING_AGENT_DIR", home / ".omp" / "agent"),
    }
    node = (find_node() if platform == actual_platform else None) or "node"
    # Always quote Windows paths, including paths with shell metacharacters.
    quote = lambda parts: " ".join('"' + part + '"' for part in parts) if platform == "windows" else shlex.join(parts)
    planned = {}
    for client in args.clients:
        client_root = client_roots[client]
        if client == "omp":
            # oh-my-pi keeps its settings in YAML: merge portable preferences over the live file, as other clients do.
            target = omp_settings_path(client_root)
            current = load_config(target) if args.install else {}
            desired = load_config(ROOT / "config/omp/config.yml")
            if platform == "linux":
                # Linux targets here are headless boxes and WSL: a visible browser has no display to open on.
                desired.setdefault("browser", {})["headless"] = True
            planned[target] = encode(target, merge(current, desired))
            # Repo extensions are copied beside the live ones; herdr's managed extension is never touched.
            for source in sorted((ROOT / "config/omp/extensions").glob("*.ts")):
                planned[client_root / "extensions" / source.name] = source.read_text(encoding="utf-8-sig")
            # Sticky rules (task subagents receive RULES.md, unlike AGENTS.md): install only a marked block and keep local rules around it.
            rules = client_root / "RULES.md"
            local_rules = rules.read_text(encoding="utf-8-sig") if args.install and rules.exists() else ""
            planned[rules] = merge_managed_block(local_rules, (ROOT / "config/omp/RULES.md").read_text(encoding="utf-8-sig"), "tool-selection")
            continue
        if client == "agy":
            # Antigravity runs the title command per state change. It passes
            # quotes through literally, so the script path must stay bare.
            script = client_root / "title.py"
            if any(char.isspace() for char in str(script)):
                print(f"Antigravity cannot launch a title script under a path with whitespace: {script}", file=sys.stderr)
                raise ValueError("whitespace in Antigravity path")
            python = "python" if platform == "windows" else "python3"
            title = {"title": {"type": "command", "command": f"{python} {script.as_posix()}"}}
            planned[script] = (ROOT / "config/antigravity/title.py").read_text(encoding="utf-8-sig")
            target = client_root / "settings.json"
            planned[target] = encode(target, merge(load_config(target) if args.install else {}, title))
            continue
        if client == "opencode":
            source = ROOT / "opencode/config/opencode.json"
        else:
            source = ROOT / "config" / client / ("settings.json" if client == "claude" else "config.toml")
        preferences = load_config(source)
        if client == "codex" and platform == "windows":
            preferences = merge(preferences, load_config(ROOT / "config/codex/windows.toml"))
        filename = "settings.json" if client == "claude" else "opencode.json" if client == "opencode" else "config.toml"
        target = client_root / filename
        current = load_config(target) if args.install else {}
        desired = merge(current, preferences)
        if client in ("claude", "grok"):
            status_cmd = quote([node, str(client_root / "statusline.js")])
            if platform != "windows":
                planned[client_root / "statusline.sh"] = unix_node_launcher(node)
                status_cmd = quote(["/bin/sh", str(client_root / "statusline.sh")])
            if client == "claude":
                desired.setdefault("statusLine", {})["command"] = status_cmd
            else:
                if platform == "windows":
                    # One unquoted filename in the TOML string, even for paths
                    # containing spaces. Arguments/quoting live inside the launcher.
                    status_cmd = str(client_root / "statusline.cmd").replace("\\", "/")
                    planned[client_root / "statusline.cmd"] = grok_windows_launcher(node)
                desired.setdefault("ui", {}).setdefault("status_line", {})["command"] = status_cmd
            planned[client_root / "statusline.js"] = (ROOT / "config" / client / "statusline.js").read_text(encoding="utf-8-sig")
        if client == "claude":
            # Function-hook plugins load from CLAUDE_CODE_PLUGIN_DIRS. Replace the
            # managed entries and keep any directory listed outside local-plugins.
            plugins_root = client_root / "local-plugins"
            plugin_dirs = []
            for plugin in sorted(path for path in (ROOT / "config/claude/plugins").iterdir() if path.is_dir()):
                plugin_dirs.append(str(plugins_root / plugin.name))
                for path in plugin.rglob("*"):
                    relative = path.relative_to(plugin)
                    # .claude-plugin/types is written by Claude Code when it loads a plugin.
                    if path.is_file() and relative.parts[:2] != (".claude-plugin", "types"):
                        planned[plugins_root / plugin.name / relative] = path.read_text(encoding="utf-8-sig")
            separator = ";" if platform == "windows" else ":"
            env = desired.setdefault("env", {})
            kept = [entry for entry in env.get("CLAUDE_CODE_PLUGIN_DIRS", "").split(separator) if entry and Path(entry).parent != plugins_root]
            env["CLAUDE_CODE_PLUGIN_DIRS"] = separator.join(plugin_dirs + kept)
            # merge() only adds keys: drop settings now set through env (env wins
            # over them anyway) and env vars that are no longer wanted.
            for key in ("autoCompactWindow", "subagentPromptCacheTtl"):
                desired.pop(key, None)
            for key in ("CLAUDE_CODE_SUBAGENT_MODEL_FORCE", "CLAUDE_CODE_SUBAGENT_PROMPT_CACHE_TTL", "ENABLE_LSP_TOOL"):
                env.pop(key, None)
            if platform == "windows":
                env.pop("SHELL", None)
                env["CLAUDE_CODE_USE_POWERSHELL_TOOL"] = "1"
            else:
                env.pop("CLAUDE_CODE_USE_POWERSHELL_TOOL", None)
                env["SHELL"] = "/bin/zsh"
        if client == "opencode":
            desired.pop("shell", None)
            # Let the target OS select its shell instead of forcing pwsh on a Mac.
            section = "mcp"
        else:
            section = "mcp_servers"
        if client == "claude":
            # User-scope MCP definitions live alongside other Claude account metadata.
            # Respect custom CLAUDE_CONFIG_DIR: Claude keeps .claude.json inside it.
            user_path = (client_root / ".claude.json") if args.home is None and os.environ.get("CLAUDE_CONFIG_DIR") else home / ".claude.json"
            user_config = load_config(user_path) if args.install else {}
            servers = user_config.setdefault("mcpServers", {})
            for name in registry:
                servers.pop(name, None)
            servers.update(mcps[client])
            planned[user_path] = encode(user_path, user_config)
        else:
            servers = desired.setdefault(section, {})
            for name in registry:
                servers.pop(name, None)
            servers.update(mcps[client])
        planned[target] = encode(target, desired)

    if "opencode" in args.clients:
        opencode_root = client_roots["opencode"]
        sources = [(ROOT / "opencode/package.json", opencode_root / "package.json")]
        sources += [(path, opencode_root / path.name) for path in (ROOT / "opencode/config").iterdir() if path.is_file() and path.name != "opencode.json"]
        for source_root, destination_root in (
            (ROOT / "opencode/skills", opencode_root / "skills"),
            (ROOT / "opencode/themes", opencode_root / "themes"),
            (ROOT / "opencode/agent-skills", home / ".agents/skills"),
        ):
            sources += [(path, destination_root / path.relative_to(source_root)) for path in source_root.rglob("*") if path.is_file()]
        for source, destination in sources:
            planned[destination] = source.read_text(encoding="utf-8-sig")

    if not args.install:
        for target, content in planned.items():
            # Custom client roots may lie outside HOME; keep outputs separated.
            relative = target.relative_to(home) if target.is_relative_to(home) else Path("external") / target.anchor.replace(":", "") / Path(*target.parts[1:])
            atomic_write(args.output / relative, content)
        print(f"Rendered {len(planned)} files to {args.output}. No live config changed.")
        return

    # Validate/read every destination before changing anything; back up the full plan.
    changes = [(target, content) for target, content in planned.items() if not target.exists() or target.read_text(encoding="utf-8-sig") != content]
    backup = home / ".local/state/ai-config/backups" / dt.datetime.now().strftime("%Y%m%d-%H%M%S-%f")
    backup.mkdir(parents=True, mode=0o700)
    index = []
    for number, (target, _) in enumerate(changes):
        saved = backup / str(number)
        if target.exists():
            shutil.copy2(target, saved)
            os.chmod(saved, 0o600)
        index.append({"path": str(target), "existed": target.exists(), "backup": saved.name})
    atomic_write(backup / "files.json", json.dumps(index, indent=2) + "\n")
    for target, content in changes:
        atomic_write(target, content)
    print(f"Installed {len(changes)} changed files. Private backup: {backup}")
    print("Restart clients and log in separately; plugins and CLI binaries are installed separately.")


if __name__ == "__main__":
    try:
        main()
    except MissingEnvironmentError as error:
        print(f"Setup stopped: {error}", file=sys.stderr)
        sys.exit(1)
    except (ValueError, OSError, json.JSONDecodeError, tomllib.TOMLDecodeError) as error:
        # Avoid dumping config values that may contain credentials.
        print(f"Setup stopped: {type(error).__name__}. Check paths, config syntax and required environment variables.", file=sys.stderr)
        sys.exit(1)
