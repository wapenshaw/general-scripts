# TITAN: i7-13700K tuning (undervolt and power limits)

Started: **2026-11-08**. Times below use **Asia/Kolkata (IST, UTC+05:30)**.
Host details are in [titan.md](../README.md); GPU tuning is in [titan-rtx-5080.md](../rtx-5080/README.md).

## Goal

Gaming first:

- **Highest possible boost clocks** for games and lightly threaded work
  (keep the stock 57x/56x P-core boost, or better). Higher ratios are
  allowed only if they hold without throttling and within the voltage cap.
- **Undervolted**, so power isn't wasted, with **no overvolting**.
- **No thermal throttling** in all-core loads such as Cinebench.

Reference point: about **29–30k Cinebench R23 multi**, a score remembered
from an earlier undervolt on this chip (not recorded at the time).

Method: find the undervolt limit at full boost ratios, add a CPU voltage
cap, then set the all-core power limit just below the point where the CPU
reaches Tj,max. The final undervolt goes in the BIOS (CPU Lite Load / AC
load line).

## Device

| Item | Value |
| --- | --- |
| CPU | Intel Core i7-13700K, stepping B0, 8P + 8E |
| Microcode | `0x137` (BIOS H.J0, 2026-09-14) |
| Stock turbo ratios | P-cores 54x (1–2c), 53x (3–8c) (ThrottleStop Turbo Groups; Intel spec 5.4/5.3 GHz); E-cores 44x (1–4c), 42x (5–8c); ring max 48x |
| Power limits at inspection | PL1 = PL2 = **253 W** (unlocked); IccMax not yet recorded |
| Intel Undervolt Protection | Disabled (HWiNFO) |
| Memory during baseline | 2× 32 GB G.Skill F5-6000J3238G32G (SK Hynix), XMP 6000 32-38-38-96 at 1.40 V |

## Tools

| Tool | Version | Notes |
| --- | --- | --- |
| HWiNFO64 | 8.54 | CSV sensor log, `devices/private/titan-sensors*.csv`; logs from the 2026-11-08/09 tuning (`titan-sensors.CSV`, `-bios1`…`-bios6`) deleted 2026-11-09 after the results were recorded here |
| Intel Processor Diagnostic Tool | 4.5.0 | Installed with `sudo`; winget's manifest is stale (Intel 403) |
| ThrottleStop | 9.7 | winget portable; voltage offsets for testing once VBS is off |
| CoreCycler | 0.11.0.3 | `C:\Software\CoreCycler\CoreCycler-v0.11.0.3\` (bundles y-cruncher, Prime95, Linpack) |
| OCCT Personal | 17.1.10 | winget |
| Cinebench R23 | 23.200 | `F:\Software\Maxon.CinebenchR23_Microsoft.Winget.Source_8wekyb3d8bbwe\` |
| Prime95 | 30.19b20 | winget |

Intel XTU 7.14.2.135 was installed and removed the same day: with VBS on,
its log reported `Platform compatibility check failure - service is limited`
(no voltage control), it has no CLI in this version, and it arms the board's
hardware watchdog. Reinstall from Intel's download page if needed.

## Contents

- [bios-settings.md](bios-settings.md) — BIOS defaults + XMP transcription and tuning plan.
- [runs.md](runs.md) — Run 0–20, BIOS visits, and review in original order; latest recorded Run 20 passed.
- [change-log.md](change-log.md) — Configuration changes and the Windows settings revert command.
- [open-items.md](open-items.md) — Validation status and remaining tuning items.
