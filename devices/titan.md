# TITAN (desktop)

Last inspected: **2026-10-25**. Times below use **Asia/Kolkata (IST, UTC+05:30)**.

## Device

| Item | Value |
| --- | --- |
| Hostname | **TITAN** |
| Motherboard | MSI MAG Z790 TOMAHAWK WIFI (**MS-7D91**) |
| CPU | Intel Core i7-13700K |
| Memory | 64 GB |
| Graphics | NVIDIA GeForce RTX 5080; Intel UHD Graphics 770 (integrated) |
| Operating system at inspection | Windows 11 Pro 26H2, build **26300.9711** |

## Incident: image right-click hang — 2026-10-24/25

### Symptom

Right-clicking a picture (`.png`, `.jpg`) in File Explorer or Directory Opus
showed a busy cursor and hung that window indefinitely. Right-click on other
file types worked.

### Diagnosis

The hang reproduced outside Explorer by building the shell context menu for an
image from a separate process. Stack dumps (`cdb -pv`) showed:

1. The menu build was blocked in `CoCreateInstance` on the out-of-process COM
   surrogate (`dllhost.exe`) hosting **Microsoft Photos' context menu
   extension** (`Photos.ShellExtension.dll`, CLSID
   `{BFE0E2A4-C70C-4AD7-AC3D-10D1ECEBB5B4}`, the "Edit with Photos" verb).
2. That surrogate was blocked in
   `PackageServer::get_InstalledLocation` → `windows_storage!IsFolderInIndexedLocation`,
   an RPC call into **Windows Search** that never returned. Every later image
   right-click queued behind it.
3. `SearchIndexer.exe` was wedged: about 25 threads were waiting on internal
   critical sections in `MSSRCH.dll`, the crawler ("Robot Thread") was blocked
   in a wait, no `SearchProtocolHost`/`SearchFilterHost` was running, and
   `ISearchCatalogManager::GetCatalogStatus` hung while item-count and
   scope-rule calls still answered.

The indexer wedged **three times** in one evening: once before any changes,
about 10 minutes after the first restart, and again shortly after an index
reset. `WSearch` sat in `StopPending` and had to be force-killed each time.
No crash or hang events were logged for the Search processes.

**Root cause of the indexer wedge: not established.** The lock owner was not
captured. The CrossDevice phone folders (below) were the first suspect, but
the indexer also wedged after their scope rules were removed.

### Changes applied

| Change | How | Undo |
| --- | --- | --- |
| Blocked the Photos context menu extension ("Edit with Photos") | [`registry-tweaks/dos/Remove_Edit_with_Photos_context_menu.reg`](../registry-tweaks/dos/Remove_Edit_with_Photos_context_menu.reg) (HKLM `Shell Extensions\Blocked`), then restarted Explorer | [`registry-tweaks/undos/Add_Edit_with_Photos_context_menu.reg`](../registry-tweaks/undos/Add_Edit_with_Photos_context_menu.reg) |
| Removed 20 index include rules (below) | Windows Search crawl scope API (`ISearchCrawlScopeManager`) | Re-add in Indexing Options → Modify |
| Excluded `C:\Users\tHeSiD\CrossDevice\` from the index | User exclude rule (same as unticking it in Indexing Options) | Indexing Options → Modify → tick `CrossDevice` |
| Full index rebuild | `ISearchCatalogManager::Reset` | — |

With Photos blocked, image right-clicks no longer depend on the indexer. They
build in about 0.5 s. Double-clicking images still opens Photos.

**Removed index include rules:** 9 folders under `G:\Movies\<title>\`, 5 under
`G:\TV\<show>\Season NN\`, `G:\Downloads\`, `F:\Software\DirectoryOpusPro\`,
`F:\Software\MSI_UEFI_FlashTool\7D91vHI\`, `Z:\Sycomp\`,
`C:\Program Files (x86)\MSI Afterburner\SDK\Doc\`, the theme
`...\Themes\Mountain (2)\DesktopBackground\` folder, and
`C:\Users\tHeSiD\CrossDevice\Muerta (1)\` plus five stale `Muerta (N)` rules.

**Index scope after cleanup:**

| Rule | Path |
| --- | --- |
| Include (Windows default) | `C:\ProgramData\Microsoft\Windows\Start Menu\` |
| Include (Windows default) | `C:\Users\` |
| Exclude | `C:\Users\tHeSiD\CrossDevice\` |
| Include | `E:\Downloads\`, `E:\Pictures\`, `E:\OneDrive\Pictures\`, `E:\Videos\` |

### Where the stray index rules came from

**Phone folders (`CrossDevice\Muerta…`): Phone Link / Cross Device.** It
exposes the phone as `C:\Users\tHeSiD\CrossDevice\Muerta (N)` (a new `N` per
reconnect; `Muerta (1)` is a live cloud-files placeholder) and adds the phone's
`DCIM` and `Pictures` folders to the **Pictures library**. Windows indexes every
library location, so each reconnect added another index rule. The library still
contained these entries after the cleanup:

```text
C:\Users\tHeSiD\CrossDevice\Muerta (5)\storage\DCIM
\\TITAN\Users\tHeSiD\CrossDevice\Muerta (5)\storage\Pictures
\\TITAN\Users\tHeSiD\CrossDevice\Muerta (1)\storage\DCIM
\\TITAN\Users\tHeSiD\CrossDevice\Muerta (1)\storage\Pictures
```

**Movie and TV folders: source unknown.** They were not in any library. Jellyfin
Server (installed and running) has no known Windows Search integration, and
Sonarr is not installed on TITAN. The pattern of recent titles and single
seasons suggests manual browsing, such as Explorer's "Add to index" infobar or
a search tool using Windows Search, but this is unconfirmed. The rules carried
no timestamp or author, and they were deleted during cleanup.

### Open items

- [ ] Turn off **Settings → Bluetooth & devices → Mobile devices → "Show my
      mobile device in File Explorer"** to stop new `Muerta (N)` folders. Not
      confirmed as done.
- [ ] Remove the four CrossDevice entries from the Pictures library. A rule for
      an exact library folder may override the parent `CrossDevice` exclude.
- [ ] Find the cause of the `SearchIndexer.exe` wedge. While it is wedged
      (Indexing Options freezes, or the status check below hangs), take an
      elevated read-only dump with symbols and `!locks` to identify the lock
      owner. Put the `cdb` commands in a file and run them with `-cf`:
      `.sympath`/`.echo` consume the rest of a `-c` command line, including `qd`,
      which leaves the debugger attached with the indexer's threads suspended.
- [ ] Optional: audit writes to
      `HKLM\SOFTWARE\Microsoft\Windows Search\CrawlScopeManager` (Security log
      event 4657) to identify the next process that adds index rules.
- [ ] "Edit with Paint" disappeared from the image menu after the cleanup
      (not blocked). Recheck once the index rebuild finishes.

### Recover a wedged indexer

```powershell
sudo pwsh -c "Get-Process SearchIndexer,SearchProtocolHost,SearchFilterHost | Stop-Process -Force; Start-Service WSearch"
```

## Recheck on Windows

These commands read the current state without changing settings:

```powershell
# Photos context menu block (expect "Edit with Photos")
(Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Shell Extensions\Blocked').'{BFE0E2A4-C70C-4AD7-AC3D-10D1ECEBB5B4}'

# CrossDevice entries in the index scope (expect only the user exclude)
Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\Windows Search\CrawlScopeManager\Windows\SystemIndex' -Recurse |
  ForEach-Object { $u = (Get-ItemProperty $_.PSPath).URL; if ($u -match 'CrossDevice') { "$($_.PSChildName): $u" } }

# Phone folders in the Pictures library
Select-String -Path "$env:APPDATA\Microsoft\Windows\Libraries\Pictures.library-ms" -Pattern 'CrossDevice'

# Search service and helper processes (no SearchProtocolHost for a long time while
# items are queued suggests a wedge)
Get-Service WSearch
Get-Process SearchIndexer, SearchProtocolHost, SearchFilterHost -ErrorAction SilentlyContinue
```

The registry stores scope URLs with a volume GUID in place of the drive letter,
for example `file:///C:\[ba5080e7-...]\Users\...`. Indexing Options shows only
folder names; the registry or the crawl scope API shows full paths.
