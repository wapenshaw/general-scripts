# Configuring AI tools

This is a personal config-and-instructions collection, not a mirror of a user's
home directory. Read `README.md` and the relevant tool's instructions before
changing either these references or an installed environment.

Portable installer defaults live under `config/` and `herdr/`; the customized
WSL profile lives under `wsl/` and is applied manually. Keep those profiles
separate rather than inserting WSL-specific paths into a shared default.

- Act on the requested tool and destination only. Personal is the default;
  configure work integrations only when explicitly requested.
- Inspect existing destination settings, paths, tools and active sessions first.
  Back up changed local files privately, then merge the requested settings.
- Keep unrelated local MCP servers, marketplaces, skills and hooks intact.
  A work setup request does not authorize exporting its content into this repo.
- Never copy organization-specific instructions, project paths, private service
  definitions, credentials, downloaded plugins, session data or runtime registries
  here. Use local or ignored destination files for work-only configuration.
- These references are not guaranteed to match the latest installed versions.
  Adapt paths, verify supported options and inspect upstream changes before
  applying recovery patches. Do not implicitly reinstall removed plugins.
- Preserve the documented themes, shortcuts, agent title behavior and local-only
  Memex indexing unless the user asks to change them. Get approval before enabling
  permission bypass or network/embedding services on a new destination.
- Deploy required helpers before enabling hooks/status-line commands. Use each
  tool's integration installer where available, and validate changed settings and
  the actual requested behavior.
- Never stop Herdr or terminate active agent sessions to apply a config change
  without explicit permission. Reload settings or restart only the affected
  plugin daemon when safe.
