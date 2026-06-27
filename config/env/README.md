# Environment Variables

This folder stores the Windows environment variables for the **TITAN** machine so they can be restored on a new system. The PowerShell scripts that read/write these files live in `../../powershell/`.

## Files

| File | Purpose | How to (re)generate |
|---|---|---|
| `user.json` | Captured user-scope env vars (HKCU\Environment). | `pwsh -File ../../powershell/tools/Export-Env.ps1` |
| `system.json` | Captured system-scope env vars (HKLM\…\Session Manager\Environment). | `pwsh -File ../../powershell/tools/Export-Env.ps1 -IncludeMachine` (admin shell) |
| `paths.json` | Custom directory layout this machine relies on (toolchain caches, portable apps, OneDrive). | Edit by hand when the layout changes. |

## Filter (always stripped on export)

The following patterns are never written to JSON. Edit `Export-Env.ps1`'s `$Filter` list to change.

- **Secrets**: `*AUTH_COOKIE*`, `*_AUTH*`, `*TOKEN*`, `*SECRET*`, `*PASSWORD*`, `*PASSWD*`, `*APIKEY*`, `*API_KEY*`, `*PRIVATE_KEY*`
- **Session**: `STARSHIP_SESSION_KEY`, `STARSHIP_SHELL`, `WT_SESSION`, `WT_PROFILE_ID`, `OPENCODE_*_WORKSPACE_ID`, `LOGONSERVER`, `SESSIONNAME`
- **Runtime/process**: `npm_config_user_agent`, `PROCESSOR_*`, `NUMBER_OF_PROCESSORS`

The list of stripped variables (with reason) is recorded under each JSON file's `filtered` array so the omission is auditable.

## Restore on a new system

```powershell
# User scope (no admin needed)
pwsh -File ..\..\powershell\Import-Env.ps1

# User + system scope (admin shell)
pwsh -File ..\..\powershell\Import-Env.ps1 -IncludeMachine

# Preview without writing
pwsh -File ..\..\powershell\Import-Env.ps1 -IncludeMachine -DryRun

# Preserve existing Path entries and append (rather than clobber)
pwsh -File ..\..\powershell\Import-Env.ps1 -MergePath
```

`Path` is normally replaced verbatim by the captured value. Use `-MergePath` to keep whatever is already on the target machine and append the captured entries (deduped).

## Notes on portability

- `Path` entries under `F:\Software\…` reference WinGet portable-install subdirs. Those subdir names are stable per machine but may differ if WinGet re-installs with a different package id. Review `Path` after `Import-Env.ps1` on a new system.
- `Z:\Packages` and `E:\OneDrive` are machine-specific drives. On a new system, either preserve the same drive letters or rewrite the captured values accordingly.
- `TEMP` / `TMP` are kept (`%USERPROFILE%\AppData\Local\Temp`).
- Machine identity (`COMPUTERNAME`, `USERNAME`, `USERPROFILE`, `OneDrive`, etc.) is intentionally retained — overwrite on import if the new machine's identity differs.
