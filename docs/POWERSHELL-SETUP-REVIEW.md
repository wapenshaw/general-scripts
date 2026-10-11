# PowerShell and package storage review

Completed on 2026-09-30. This records the applied Windows setup and checks.
For installation and troubleshooting, see [the shell setup guide](../powershell/profile/README.md).

## Cleanup applied

- nvm v2.0.0 manages Node 26.8.2, with installations at `Z:\Packages\nvm\runtime`
  and downloads at `Z:\Packages\nvm\.cache`. The small nvm launcher remains in its
  supported per-user installation location. mise was uninstalled and archived.
  Link mode is selected because 2.0.0's shim trust checks blocked npm after its
  package update; `nvm reshim` and `nvm doctor --autofix` did not repair that state.
  `npm outdated -g` succeeds in link mode without the previous npmrc warnings.
- pnpm 12.4.1 is a standalone executable at `Z:\Packages\pnpm\bin\pnpm.exe`,
  independently of Node/Corepack. Its existing global config was retained; npmrc
  entries causing npm's unknown-setting warnings were removed.
- uv owns Python and CLI environments. Poetry 2.3.4 and deptry 0.25.1 were rebuilt
  against retained uv Python 3.14. Broken pipx launchers/environments were archived.
- Rust toolchains moved to `Z:\Packages\.rustup`; the previous home path forwards
  to it, and a source backup was retained. Package data and caches are manifest-managed.
- The profile uses a static loader and explicit manifest, local PSFzf deployment,
  setup-time dependencies, prompt initialization after work settings, and opt-in
  Visual Studio activation. Empty/obsolete profile modules were retired.
- Managed cache variables use User scope. Matching Machine duplicates, obsolete
  pyenv settings and developer-shell PATH additions were removed. The intentional
  JDK 17 User JAVA_HOME override is retained; setup preserves it unless -JavaHome
  is supplied explicitly. Java on Machine PATH can still resolve to JDK 26.
- Vendor-managed IDEs and .NET/Java/Go/CUDA retain their supported install locations;
  managed runtimes and development stores use Z:, consistent with Microsoft's
  [Dev Drive guidance](https://learn.microsoft.com/windows/dev-drive/).
- The July snapshot is archived under `config/env/snapshots`. Fresh install applies
  `development.json`; export defaults outside the repo and import previews by default.

## Validation after cleanup

- All PowerShell scripts parse; `git diff --check` reports no whitespace errors.
- Profile smoke check: no recorded load errors, PSFzf imports from the local store,
  no automatic developer environment, and no Git wrapper. Observed startup was
  approximately 765 ms for the checked configuration with prompt disabled.
- `vsdev` activates MSVC with x64 host and x64 target.
- `npm outdated -g` exits 0 without the previous unknown-setting warnings.
- Effective pnpm/uv/Poetry/NuGet/Go storage locations point at Z:. NuGet temporary
  scratch retains the standard TEMP location on C:.
- Rust reports `Z:\Packages\.rustup` as its home. Node and npm resolve through
  nvm's Z: junction, and pnpm resolves directly from `Z:\Packages\pnpm\bin`.
- All managed storage directories exist and match the manifest. Neither persisted
  PATH has empty or missing entries; no managed cache variables remain in Machine
  scope and no empty/obsolete pyenv/mise/link-mode variables remain.
- `-WhatIf` is idempotent on the cleaned machine and preserves intentional JDK 17.

Private pre-cleanup backups are under
`%LOCALAPPDATA%\PowerShellSetup\backups\20260930-110307`; per-apply backups are under
`environment-backups` and `profile-backups`. Archived tool installations are recovery
copies, not active development locations. Restart existing applications before
checking their environment: they retain old inherited values until relaunched.

## Codex updater investigation

The reported command is Codex's standalone updater, which starts Windows PowerShell
with `CODEX_NON_INTERACTIVE=1` and invokes the installer. Both PowerShell 7.6.6 and
Windows PowerShell 5.1 reached OpenAI release metadata, GitHub release metadata and
npm metadata with HTTP 200. No persisted or inherited proxy overrides were found
in the inspected environment. Both resolve the same standalone Codex installation.

After cleanup, the actual `codex update` command ran that child-process updater and
completed successfully, reporting version 0.159.2. The intermittent failure was
not reproduced; the evidence does not establish a TLS or profile cause. Previously,
this session's sandbox had restricted network/filesystem access, which could explain
some failures of commands run by an agent, but it does not prove the cause of the
reported updater failure. No TLS verification or network security was disabled.

`powershell/diagnostics/Test-ShellConnectivity.ps1` preserves a read-only way to
compare shell versions, effective commands and update endpoint access. The official
[standalone installer](https://releases.openai.com/codex/install.ps1) was inspected.

## One profile for VS Code and Windows Terminal

Both observed hosts run `C:\Program Files\PowerShell\7\pwsh.exe`. VS Code's regular
terminal adds `-NoExit -Command` to initialize shell integration. The first version
of the new loader skipped all `-Command` invocations, causing a bare VS Code shell
without profile aliases, helpers or prompt initialization. This was corrected to
allow interactive `-NoExit` launches and the PowerShell extension's VS Code host.
Ordinary script/command invocations still skip shell UI.

The live `Microsoft.VSCode_profile.ps1` also forwarded to an old local loader that
referenced the retired `user_profile.ps1` and eagerly loaded function files. That
loader was archived. Separate ConsoleHost and VS Code profile files were backed
up and removed. Both now use the same CurrentUserAllHosts entry point at
`E:\OneDrive\Documents\PowerShell\profile.ps1`, which loads
`C:\Users\tHeSiD\.config\powershell\profile.ps1`. The installer reproduces this
layout; there is no separate VS Code profile to maintain.

After the correction, an interactive `pwsh -NoExit -Command` check recorded zero
profile load errors, PSFzf 2.7.12 and Starship initialization with a normal terminal
type. A plain `pwsh -Command` check still skipped the interactive profile. These
checks exercised the launch behavior; they did not inspect command resolution
inside the user's existing VS Code terminal sessions.

VS Code settings inspected in the repo, User settings and named User profiles had
no explicit terminal PATH override. The existing VS Code shells predated the loader
fix, so they needed replacing. Fully quit VS Code and reopen it from Start after
environment changes; opening a new tab can inherit the existing parent's old
environment. Specific commands reported as differing were not supplied, so no
additional executable-specific cause was established.

For future comparisons, follow [VS Code troubleshooting](../powershell/profile/README.md#vs-code-and-terminal-differences).
Microsoft documents [profile scopes](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_profiles)
and [VS Code shell integration](https://code.visualstudio.com/docs/terminal/shell-integration).

## Configuration ownership

| Concern | Owner |
| --- | --- |
| Desired User variables and storage directories | `config/env/development.json`, applied by `Set-DevPackagePaths.ps1` |
| Node versions and per-version npm globals | nvm v2, explicit version selection in link mode |
| pnpm executable and storage | Standalone pnpm; storage in global `config.yaml` |
| Python interpreters and Python CLI environments | uv |
| PowerShell startup | Shared AllHosts entry point and local manifest-based loader |
| Profile dependencies | Local module store populated during installation |
| MSVC/SDK environment | `vsdev`, separately activated in each process |
| Vendor installations and Machine PATH | Vendor installers |
| Intentional Java 17 override | Existing User `JAVA_HOME`; explicit `-JavaHome` for setup changes |
| Environment exports | Private recovery artifacts; explicit directory and `-Apply` for restore |

`Z:\Packages` contains runtimes, installed tools and caches. It is not a disposable
cache directory. The storage root option supports initial setup; moving an existing
installation requires migration with the owning tool.

## Repository cleanup

- Removed obsolete mise startup, empty function module, automatic Visual Studio
  activation module and deprecated `User-Profile.ps1` stub.
- Archived the July environment snapshot under `config/env/snapshots`; fresh setup
  uses the manifest. `Import-Env.ps1` now requires an explicit backup directory.
- Updated the root README, fresh-install playbook, profile guide, environment
  directory map and agent guidance to describe the same layout.
- Replaced superseded audit proposals with this applied-state record. The original
  live configuration and retired installations remain in private recovery backups.
