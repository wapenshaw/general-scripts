# Development environment

`development.json` is the desired configuration. `paths.json` documents the layout;
`snapshots/` contains historical recovery data and is not used by setup.

```powershell
pwsh -NoProfile -File ./powershell/profile/Set-DevPackagePaths.ps1 -WhatIf
pwsh -NoProfile -File ./powershell/profile/Set-DevPackagePaths.ps1
pwsh -NoProfile -File ./powershell/profile/Install-NodeToolchain.ps1
```

The default root is `Z:\Packages`. Override with `-Root` or edit the manifest.
Settings use User scope; dependencies and caches are available to terminals, IDEs
and scripts without running a shell profile. Node belongs to nvm v2, Python to uv,
and pnpm uses a standalone binary and global `config.yaml`. Corepack is not enabled.

The manifest covers Cargo/Rustup, Go, Gradle, Maven, npm, pnpm, pip, uv, Poetry,
NuGet, Bun and TorchInductor storage. Runtime directories and installed packages
are persistent data; use each manager's cache command to clear disposable data.
Vendor-managed IDEs and system SDKs retain their supported installation locations.

`-CleanPath` removes legacy pyenv/mise and persisted Visual Studio developer-shell
PATH additions. `-RemoveMachineDuplicates` requires elevation and removes only
matching or empty managed Machine variables and missing nvm paths. Other machine
settings, secrets and application settings are retained. Changes and previous
registry value types are saved under `%LOCALAPPDATA%\PowerShellSetup`.
`JAVA_HOME` is preserved unless `-JavaHome <installed-JDK>` is provided explicitly.

## Backups

Export writes sanitized snapshots outside the repo by default:

```powershell
./powershell/tools/Export-Env.ps1
./powershell/tools/Export-Env.ps1 -IncludeMachine  # elevated
```

Do not use historical captured PATH as fresh-install configuration. For deliberate
recovery, supply a directory containing `user.json` and optionally `system.json`:

```powershell
./powershell/tools/Import-Env.ps1 -ConfigDir C:/path/to/export -MergePath
./powershell/tools/Import-Env.ps1 -ConfigDir C:/path/to/export -MergePath -Apply
```

Import previews unless `-Apply` is passed and saves a pre-import snapshot before
writing. Review exported data before sharing it: name-based secret filtering
cannot identify credentials hidden inside an arbitrary value.

See [the PowerShell setup guide](../../powershell/profile/README.md) for profile
installation, plugin controls, developer-shell activation and connectivity diagnostics.
