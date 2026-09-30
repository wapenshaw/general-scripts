# Windows shell and development setup

Desired storage settings live in [development.json](../../config/env/development.json).
Use User environment variables for this personal workstation. Machine PATH belongs
to vendor installers. Historical environment snapshots are backups, not setup input.

## Setup

```powershell
# PowerShell 7, with Z: available
pwsh -NoProfile -File ./powershell/profile/Set-DevPackagePaths.ps1 -WhatIf
pwsh -NoProfile -File ./powershell/profile/Set-DevPackagePaths.ps1
pwsh -NoProfile -File ./powershell/tools/Install-Essentials.ps1
pwsh -NoProfile -File ./powershell/profile/Install-NodeToolchain.ps1
# Install uv separately if missing, then use uv for Python and Python CLI tools.
uv python install 3.14 --default
uv tool install --python 3.14 poetry
uv tool install --python 3.14 deptry
pwsh -NoProfile -File ./powershell/profile/Install-Profile.ps1
```

Node is managed by nvm v2 in link mode. Select versions explicitly with `nvm use`.
This avoids nvm 2.0.0 shim trust failures after npm updates; automatic per-directory
shim switching is not enabled. The runtime versions are pinned in the
manifest. pnpm is a standalone executable, with globals and its store under
`Z:\Packages\pnpm`; Corepack is not enabled. uv owns Python interpreters and Python
CLI environments. Keep projects and virtual environments on Z: alongside the caches.

Vendor-managed Visual Studio, .NET, Go, Java and CUDA installations retain their
supported locations; development stores/caches use the Dev Drive. `RUSTUP_HOME`
puts Rust toolchains on Z: and `CARGO_HOME` puts Cargo packages/binaries there.
Existing `JAVA_HOME` is preserved, including the intentional JDK 17 override on this
machine. Set it explicitly during setup with `Set-DevPackagePaths.ps1 -JavaHome <JDK>`;
the installer does not infer the intended JDK from PATH.

## Profile behavior

- A thin `profile.ps1` (AllHosts) loads `$HOME\.config\powershell\profile.ps1`.
- `installed-profile.json` explicitly selects modules; stale/excluded files do not run.
- Plugins are deployed during installation to `$HOME\.local\share\powershell\Modules`.
  Existing external module stores remain discoverable.
- Default plugin is PSFzf. Add Git completion with `-Plugins PSFzf,posh-git`.
- `-SkipPlugins` supports offline deployment; startup never installs modules.
- Disable plugins with `PS_DISABLE_PLUGINS=1` or `PS_PLUGINS=none`.
- `-Work` retains private installed work settings; prompt initialization is last.
- Existing Starship config is retained unless `-StarshipTheme` is specified.
- Command/script invocations skip interactive startup. Opt in with `PS_PROFILE_IN_SCRIPTS=1`.
  Interactive `-NoExit -Command` launches (including VS Code shell integration) and
  the PowerShell extension's VS Code host load the shared profile normally.
- ConsoleHost and VS Code both use AllHosts; separate host profile files are removed
  during installation after being backed up.
- Use `vsdev` / `Enter-DevShell` for the x64 Visual Studio developer environment.
  Ordinary shells do not add compiler/SDK paths.
- Windows PowerShell 5.1 has an independent minimal profile; Python/Conda is not
  activated by it. The PowerShell 7 loader is not compatible with Windows PowerShell 5.1.

Reinstalling backs up the live configuration and entry points under
`%LOCALAPPDATA%\PowerShellSetup\profile-backups`. Uninstall restores the first
saved configuration and entry points, retaining new dependencies for recovery.

## VS Code and terminal differences

Both Windows Terminal and VS Code's regular integrated terminal use PowerShell 7's
CurrentUserAllHosts profile (`$PROFILE.CurrentUserAllHosts`). That thin entry point
loads `~/.config/powershell/profile.ps1`. The PowerShell extension's Integrated
Console also uses AllHosts when profile loading is enabled. There is no separate
`Microsoft.VSCode_profile.ps1` or `Microsoft.PowerShell_profile.ps1` to maintain.
Windows PowerShell 5.1 remains a separate shell with a minimal profile.

VS Code starts regular integrated PowerShell terminals with `-NoExit -Command`
for shell integration. An earlier loader skipped every `-Command` invocation,
which left VS Code without Starship, aliases and profile helpers. The loader now
recognizes interactive `-NoExit` launches and the extension's VS Code host.
Ordinary script/command invocations continue to skip shell UI.

If a command works in one shell but fails in another:

1. Fully quit all VS Code windows, then reopen VS Code from Start and create a new
   terminal. Existing shells keep their loaded functions; VS Code can also retain
   the environment inherited when it started. Opening a tab does not guarantee
   that the parent application's PATH has refreshed.
2. Compare the following in both shells. Replace `node` with the failing command:
   ```powershell
   $PSVersionTable.PSVersion
   $PSHOME
   $Host.Name
   $PROFILE | Select-Object *
   Get-Command node -All | Select-Object Name, CommandType, Source, Definition
   $script:ProfileLoadErrors
   ```
3. For missing aliases/functions (`z`, `vsdev`, `uvdev`), check profile loading and
   any `-NoProfile` launch argument. For missing external executables, compare
   `$env:Path` and command resolution. Check User, active VS Code profile, and
   workspace settings for terminal arguments/environment overrides. For the
   extension console, ensure `powershell.enableProfileLoading` is enabled and
   PowerShell 7 is selected.
4. MSVC/SDK commands require `vsdev` in each shell where they are needed. This
   process-local environment is deliberately not persisted to User PATH.

Startup does not rewrite the entire process PATH from registry values; session
additions made by development tools remain available. Do not save a shell's
process PATH back into User PATH.

The [cleanup record](../../docs/POWERSHELL-SETUP-REVIEW.md) documents the migration,
validation results, backup locations and unresolved Codex connectivity report.

## Cleanup and diagnostics

```powershell
# Preview/remove legacy User PATH entries, pyenv settings and redundant uv link mode
./powershell/profile/Set-DevPackagePaths.ps1 -CleanPath -WhatIf
./powershell/profile/Set-DevPackagePaths.ps1 -CleanPath
# Elevated shell: remove matching/empty Machine cache variables and missing nvm paths
./powershell/profile/Set-DevPackagePaths.ps1 -RemoveMachineDuplicates

# Read-only endpoint and command-resolution comparison; no installer execution
pwsh -NoProfile -File ./powershell/diagnostics/Test-ShellConnectivity.ps1 -PersistedPath
powershell -NoProfile -File ./powershell/diagnostics/Test-ShellConnectivity.ps1 -PersistedPath
codex update
```

Storage setup backs up changed registry values and config files to
`%LOCALAPPDATA%\PowerShellSetup\environment-backups`. `-WhatIf` makes no changes.
pnpm settings live in its global `config.yaml`, not `.npmrc`. npm/pip caches use
the manifest environment variables; credentials and unrelated tool settings are retained.

After changes, restart terminals, editors and Codex so they inherit the new settings.
Do not persist an application's process PATH: it can contain temporary Codex paths
and Visual Studio developer-shell state. `Z:\Packages` includes installed runtimes
and tools as well as caches; do not delete the whole directory to clear caches.

Changing the storage root after installing runtimes requires a tool-specific migration;
-Root is intended for initial setup and does not move existing runtime environments.
