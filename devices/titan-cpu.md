# TITAN: i7-13700K tuning (undervolt and power limits)

Started: **2026-11-08**. Times below use **Asia/Kolkata (IST, UTC+05:30)**.
Host details are in [titan.md](titan.md); GPU tuning is in [titan-rtx-5080.md](titan-rtx-5080.md).

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

## BIOS settings: defaults + XMP — 2026-11-08 08:30–08:33

Transcribed from F12 screenshots taken after **Load Optimized Defaults + XMP**
(originals: `devices/private/bios-screenshots-config/*.bmp`). Saved OC
profiles in the same folder: `STock.ocb` (08:34) and `MsOcFile.ocb` (08:35,
taken right before rebooting); the two differ in 22 bytes. MSI's format is
binary and not decoded here.

Header readout: Click BIOS 5, BIOS **E7D91IMS.HJ0**, build 09/14/2026,
BIOS mode CSM/UEFI, CPU speed 5.60 GHz, DDR 6000 MHz, memory 65536 MB,
VCore 1.380 V (idle, in BIOS), CPU 47–52 °C, motherboard 44–48 °C,
System 5V 5.010–5.020 V, System 12V 12.096 V.

Where a setting shows two values, the first is the current value the BIOS
displays beside it and the bracketed one is the setting itself.

### OC (main page)

| Setting | Value |
| --- | --- |
| OC Explore Mode | Expert |
| CPU Cooler Tuning | **Intel Default Se…** (Intel Default Settings; label truncated) |
| P-Core Ratio Apply Mode | All Core |
| P-Core Ratio | Auto |
| Adjusted CPU Frequency | 3400 MHz |
| Per P-Core Ratio Limit | Auto |
| E-Core Ratio Apply Mode | All Core |
| E-Core Ratio | Auto |
| Adjusted E-Core Frequency | 3400 MHz |
| Per E-Core Ratio Limit | Auto |
| AVX Support | Auto |
| CPU Ratio Offset When Running AVX | Auto |
| AVX Voltage Guardband Scale | 128 / Auto |
| Ring Down Bin | En / Auto |
| Ring Ratio Min | Auto |
| Ring Ratio | Auto |
| Adjusted Ring Frequency | 3100 MHz |
| GT Ratio | Auto |
| Adjusted GT Frequency | 1600 MHz |
| CPU Base Clock (MHz) | 100.00 |
| CPU Base Clock Apply Mode | Auto |

### DRAM

| Setting | Value |
| --- | --- |
| Extreme Memory Profile (XMP) | **Enabled** — DDR5 6000 MHz 32-38-38-96 1.400 V |
| DRAM Reference Clock | 100 / Auto |
| CPU IMC : DRAM Clock | Gear2 / Auto |
| DRAM Frequency | 30 / Auto |
| Adjusted DRAM Frequency | 6000 MHz |
| Memory Try It! | Disabled |
| Memory Extension Mode | Disabled |
| DRAM Timing Mode | Link |
| Memory Fast Boot | Auto |
| Memory Fast Boot When OC Fail | Disabled |

### Voltages

| Setting | Value |
| --- | --- |
| CPU Core Voltage Mode | Auto |
| CPU Core Voltage | 1.380 V / Auto |
| CPU GT Voltage Mode / Voltage | Auto / Auto |
| CPU E-Core L2 Voltage Mode / Voltage | Auto / Auto |
| CPU SA Voltage Mode | Auto |
| CPU SA Voltage | 1.202 V / Auto |
| CPU VDDQ Voltage | 1.300 V / Auto |
| CPU VDD2 Voltage | 1.292 V / Auto |
| CPU 1.05 Voltage | Auto |
| CPU 1.8 Voltage | Auto |
| CPU AUX Voltage | 1.800 V / Auto |
| CPU / GT / RING / SA / E-Core L2 / MC PLL SFR Voltage | Auto (all) |
| DRAM High Voltage Mode | Disabled |
| DRAM Voltage Mode | Link |
| DRAM Voltage | 1.400 V / Auto |
| DRAM VDDQ Voltage | 1.400 V / Auto |
| DRAM VPP Voltage | 1.800 V / Auto |
| PCH 0.82 Voltage | Auto |

### Other settings (OC page)

| Setting | Value |
| --- | --- |
| Memory OC Retry Count | 2 |
| CPU Memory Changed Detect | Enabled |
| OC Quick View Timer | 3 Sec |

### DigitALL Power

All **Auto**: CPU Loadline Calibration Control, CPU Loadline Saturation
Control, CPU Over Voltage Protection, CPU Over Current Protection, CPU
Switching Frequency, CPU VRM Over Temperature Protection, CPU GT Loadline
Calibration Control, CPU GT Over Voltage Protection, CPU GT Over Current
Protection, CPU GT Switching Frequency, CPU GT VRM Over Temperature
Protection, CPU AUX Loadline Calibration Control.

### Advanced CPU Configuration

| Setting | Value |
| --- | --- |
| BCLK 100MHz Lock On | Disabled |
| Hyper-Threading | Enabled |
| Per P-Core Hyper-Threading Control | Disabled |
| Per P-Core Control / Per E-Core Control | Disabled / Disabled |
| Active P-Cores / Active E-Cores | All / All |
| Legacy Game Compatibility Mode | Disabled |
| Intel Adaptive Thermal Monitor | Enabled |
| Intel C-State | En / Auto |
| C1E Support | En / Auto |
| Package C State Limit | Auto |
| Intel Speed Shift Technology | Auto |
| EIST | Enabled |
| Intel Turbo Boost | Enabled |
| Intel Turbo Boost Max Technology 3.0 | Enabled |
| Enhanced Turbo | Auto |
| CPU TDP Toggle Control | Disabled |
| Long Duration Power Limit (W) | **253 W** / Auto |
| Long Duration Maintained (s) | 128 s / Auto |
| Short Duration Power Limit (W) | **253 W** / Auto |
| CPU Current Limit (A) | **307 A** / Auto |
| GT Current Limit (A) | 30 A / Auto |
| CPU Lite Load Control | **Normal** |
| CPU Lite Load | **Mode 1** / Auto |
| CPU Over Temp. Protection | 100 °C / Auto |
| CPU Under Voltage Protection | **Dis** / Auto |
| CPU Ratio Extension | Dis / Auto |
| CPU PLL Banding Ratio | 0 / Auto |
| CPU FLL OC Mode | Mode 0 / Auto |
| TVB Ratio Clipping | En / Auto |
| TVB Ratio Clipping Enhanced | En / Auto |
| TVB Voltage Optimizations | Dis / Auto |
| TVB Points Configuration | (submenu, not captured) |
| PVD Ratio Threshold | 0 / Auto |
| SA PLL Frequency | 3200 MHz / Auto |
| Core HW Fixup During TSC Copy | En / Auto |
| **IA CEP Support** | **En** / Auto |
| GT CEP Support | En / Auto |
| CPU VR Voltage Limit | Auto (no cap set) |
| GT VR Voltage Limit | Auto |
| DMI Link Speed | Gen4 |

Also seen in BIOS search: MSI Driver Utility Installer = Enabled.

**Notes for tuning:** power limits are Intel's Performance profile (253/253 W,
307 A). Lite Load is on **Auto, showing Mode 1** under Intel Default (HWiNFO 09:5x: **IA Domain Loadline AC/DC = 1.100 / 1.100 mΩ**, Intel spec; the "Mode 1" label does not mean the lowest load line here. The 07:38 export under the old OC settings showed 0.010 / 0.010 mΩ)
Settings. **IA CEP is enabled**, so an over-deep undervolt may show up as a
lower score rather than a crash. Undervolt Protection is disabled, and no CPU
VR voltage cap is set.

## Run 20: CoreCycler P-cores 4–5 (preferred), 15 min each, P +2 / E +2 — 2026-11-09 01:33–02:04 — PASS

Prime95 SSE Huge, 1 thread, `coresToIgnore` all but 4 and 5, `runtimePerCore = 15m` (E-core config backed up as `config.ini.ecores-run16`). Log `CoreCycler_2026-11-09_01-33-38_PRIME95_SSE.log`: **"No core has thrown an error", "No WHEA errors were observed"**; no WHEA in the System log since 01:03:39. `bios6`: P-core 4 avg 5346 MHz, P-core 5 avg 5401 MHz, max 5586 (56×) but **only ~3 % of samples at 56×** (background load usually keeps ≥3 cores active → 55×), Vcore max 1.302 / 1.276 V, Core Max ≤ 70 °C. Caveat: the 56× (1–2 active cores) state is barely exercised by any test so far; the 01:03 WHEA on APIC 32 remains unexplained. Watch Event Viewer for further WHEA Id 19; if one recurs on a P-core at light load, cap the 1–2-core groups at 55× (or drop the P offset to +1) rather than reducing the undervolt.

## Run 19: y-cruncher all-core AVX2 at P +2 / E +2, PL 220, −0.100 — 2026-11-09 01:16–01:33 — PASS (1 transient flag)

`yc-allcore.cfg` (24 threads, 16 GB, 8 × 120 s, StopOnError). Load span 01:16:28–01:32:42 = full 960 s; **no WHEA**. `bios6` 01:16:35–01:32:45 (485 rows): package 207.7 W avg / 220.4 max, P-core 0 5260 MHz avg, E-core ~4.12 GHz avg, Vcore 1.235 avg / 1.318 max, **VR current 212 A max** (Run 15: 196), Core Max 84.5 avg / 95 peak. **1 of 485 samples** with thermal flag, 01:20:34 (start of test 3), P-cores 5 and 7, Core Max reading 65 °C, package 152 W: same sub-second test-transition spike as Run 15 (2 flags), not sustained throttling.

## Run 18: Cinebench R23 multi at P +2 / E +2, PL 220, −0.100 — 2026-11-09 01:05–01:16 — CLEAN

Score **29,493** (Run 13 at E stock: 29,231, +0.9 %). No WHEA during or after the run. `bios6` 01:05:45–01:15:55 (305 rows): package 216.2 W avg (at limit ~99 %), P-core 0 5287 MHz avg, E-cores ~4.14–4.19 GHz avg (4389 max), ring 4456 MHz avg, Vcore 1.235 avg / 1.302 max, VR current 188 A max, **Core Max 89.7 °C avg / 95 °C peak** (Run 13: 88.7 / 92), **0 thermal-throttle flags**. E +2 takes a share of the same 220 W, so the gain is small and runs ~1–3 °C hotter.

## BIOS visit 4: PL back to 220/220, offset back to −0.100 (P +2 / E +2 kept) — 2026-11-09, boot 00:58:18

User confirmed the 235 W / −0.105 values were left over from the +3 attempts and reverted them. HWiNFO (`titan-sensors-bios6.csv`, from 01:04:25) confirms PL1/PL2 220 W, IA/CLR offset −0.100, IA OC ratio limit 56×. Lite Load / LLC assumed unchanged (no change-summary photo yet). **One corrected WHEA at 01:03:39 (Id 19, Processor Core, Internal parity error, APIC 32 ≈ P-core 4)** before logging started, at light load. WHEA history: none from 11-08 08:37 through 22:55 (all P +2 / E stock testing); all errors since have been with E +2 in place.

## Run 17: Cinebench R23 multi at P +2 / E +2, **PL 235 W, offset ≈ −0.105** — 2026-11-09 00:33 — FAIL (WHEA)

HWiNFO (`bios5`) shows visit 3 also changed **PL1/PL2 220 → 235 W** and **IA/CLR offset −0.100 → −0.104 V** (likely −0.105 in BIOS); not in the user's description, confirm. Load began 00:33:29; P-cores held **55× all-core at 227–231 W**, Vcore ~1.25 V, Core Max 91 °C. **4 corrected WHEA (Id 19, Processor Core, "Internal parity error") at 00:33:33 (APIC 40 ×2), 00:33:36 (Id 2), 00:33:40 (APIC 16)**: APIC 40/16 are most likely P-cores 5 and 2. Cinebench exited ~00:33:44 with no score. Interpretation: at 235 W the power limit no longer pulls all-core below 55×, so 55× all-core at −105 is under-volted; E-cores were at 42× (all-core group) and are not implicated. Next: PL back to 220/220 and offset −0.100, keep P +2 / E +2, re-run Cinebench.

## Run 16: CoreCycler E-cores 8–15 at E +2 (44×), P +2, −100 — 2026-11-08 23:44 → 11-09 00:32 — PASS

Prime95 SSE Huge FFT, 1 thread, 6 min per core, `coresToIgnore = 0–7` (P-core config backed up as `config.ini.pcores-run12`). Log `CoreCycler_2026-11-08_23-44-20_PRIME95_SSE.log`: **"No core has thrown an error", "No WHEA errors were observed"**. HWiNFO (`titan-sensors-bios5.csv`, 1440 rows): each E-core held **4390 MHz (44×)** while tested; Vcore 1.256 V avg / 1.300 V max; package 47 W avg; Core Max 65 °C peak.

## BIOS visit 3: P-core +3 attempt (failed), now P-core +2 / E-core +2 — 2026-11-08 22:55–23:24

User report: P-core Turbo Ratio Offset **+3 crashed instantly**; settled on **P +2, E-core +2**. No change summary photo yet; exact per-boot settings unknown. Event log (System) and minidumps for the window:

| Boot | Ended | How | Bugcheck (minidump header) |
|---|---|---|---|
| 23:01:58 | ~23:02:09 (≈11 s after boot) | Kernel-Power 41, unexpected | 0x50 PAGE_FAULT_IN_NONPAGED_AREA (dump 23:04:31) |
| 23:04:22 | ~23:04:34 (≈12 s) | Kernel-Power 41, unexpected | no dump |
| 23:08:58 | 23:09–23:15 | Kernel-Power 41 | **0x101 CLOCK_WATCHDOG_TIMEOUT** (p1 = 0x8; a core stopped answering interrupts, typical of CPU instability) |
| 23:15:19 | 23:17:01 | clean restart by user (BIOS) | — |
| 23:20:19 | ~23:20:30 (≈11 s) | Kernel-Power 41, unexpected | 0x50 (dump 23:20:28) |
| 23:23:56 | — (current) | — | — |

User confirmed **every crash above was a P-core +3 attempt**: +3 is unstable at −100 mV (3 boots died within ~12 s, one lasted a few minutes then 0x101). None of the crashes were at P +2 / E +2. **P-core ceiling at −100: +2.** No WHEA events in the window. Current boot check (23:4x, Windows `% Processor Performance` × 3.4 GHz nominal): an E-core loaded alone (LP 20) ran **~4.39 GHz = 44×** (stock 42×), confirming **E-core +2** is active. E-core +2 is **unvalidated**: needs CoreCycler on cores 8–15 and Cinebench vs Run 13 (29,231). HWiNFO logging was not running after the reboots (`titan-sensors-bios4.csv` last written 22:55).

## Run 15: y-cruncher all-core AVX2 at +2, PL 220 (BIOS) — 2026-11-08 15:32–15:49 — PASS (2 transient flags)

Same config as Run 11 (`yc-allcore.cfg`, 24 threads, 16 GB, 8 tests × 120 s, StopOnError true). Load span 15:32:31–15:48:43 — the full 960 s, so no test stopped on an error; window left open at the end. WHEA since boot: none.

| Metric | Run 15 (+2) | Run 11 (stock ratios) |
|---|---|---|
| Package power avg / max | 207.1 / 220.4 W | ~213 / 220 W |
| P-core 0 clock avg (min) | 5275 (4888) MHz | ~5190 (4888) MHz |
| Core Max avg / max | 83.6 / **93 °C** | — / 95 °C |
| Vcore max | 1.32 V | 1.28 V |
| VR current max | 196 A | 199 A |
| Thermal-flag samples | **2 of 486** | 0 of 483 |

The 2 flagged samples (15:36:31 and 15:48:41) are both at y-cruncher test transitions, both on P-core 7 only, with Core Max reading just 65–69 °C and the package at 220 W. That pattern is a sub-second hotspot spike when a fresh AVX2 test starts at 55× all-core, before the 220 W limit pulls clocks back. It is not sustained throttling. If it matters, the fix is capping the 5–8-active-core turbo groups at 54×, not lowering the single-core +2.

## BIOS visit 2: P-core Turbo Ratio Offset +2, PL 220/220 in BIOS — 2026-11-08 13:22:51

Change summary (photo): P-Core Ratio Apply Mode All Core → **Turbo Ratio Offset**; P-Core Turbo Ratio Offset Value Auto → **+2**; Long Duration Power Limit Auto → **220**; Short Duration Power Limit Auto → **220**. Everything else as visit 1 (Adaptive + Offset −0.100, IccMax 307, VR Voltage Limit Auto, CEP Enabled). ThrottleStop not running from here on — limits come from BIOS only. Log `titan-sensors-bios4.csv` (from ~13:28).

Why BIOS: ThrottleStop Turbo Groups (55/55/54×6, with and without its `Overclock` box) were accepted but had no effect — a single loaded core stayed at 54× (P-core 4) / 53× (P-core 1). The MSI per-core limits written at boot win over MSR 0x1AD.

Observed behaviour: MSI's offset raises the ratio groups, not the favoured-core split — any P-core reaches **56× (5.59 GHz) with 1–2 cores active** and **55× (5.49 GHz) with 3+ active**. In practice background activity keeps 3+ cores awake, so sustained single-thread runs at 5.49 with bursts to 5.59.

## Run 12: CoreCycler P-cores 0–7 at +2 — 2026-11-08 13:30–14:20 — PASS

P95 SSE Huge FFT, 1 thread, 6 min/core, `coresToIgnore = 8–15` (E-cores unchanged and already passed at −100; config backup `config.ini.run4bak`). Log `CoreCycler_2026-11-08_13-30-23_PRIME95_SSE.log`: "No core has thrown an error", "No WHEA errors were observed".

- Peak per-core VID 1.296–1.323 V (max core 3); peak Vcore 1.306 V. Single-core temps 69–74 °C.

## Run 13: Cinebench R23 multi at +2, PL 220 (BIOS) — 2026-11-08 14:32–14:42 — CLEAN

| Metric | Run 13 (+2) | Run 10 (stock ratios) |
|---|---|---|
| Score | **29,231** | 28,927 |
| Package power avg | 216.8 W (PL flag 100%) | 214.8 W (PL flag 15%) |
| P-core 0 clock avg | 5289 MHz | 5290 MHz |
| Ring avg | 4477 MHz | — |
| Core Max avg / max | 88.7 / **92 °C** | 90.7 / 93 °C |
| Thermal flags | **0** | 0 |
| Vcore avg / max | 1.239 / 1.304 V | — |

All-core is now power-limited rather than ratio-limited, so heat is unchanged; the +1% is ring clock and run-to-run noise. An earlier attempt 14:21–14:31 ran the full 10 min (93 °C, 0 flags, no crash) but the score was not captured (`2>&1 | Out-String` capture; use `| Select-String 'CB '`).

## Run 14: Cinebench R23 single-core at +2 — 2026-11-08 14:43–14:53 — clocks only

Load ran 14:43–14:53; Cinebench then sat idle until 15:31 and printed no score (no crash report). Clock data from the busiest core per sample: **5486 MHz in 90% of samples, 5586 MHz in 10%**; busy-core VID avg 1.238, **max 1.310 V**; package avg 38.6 W; Core Max 58 °C. No stock single-core baseline exists, so the score was not re-run.

## Run 11: y-cruncher all-core AVX2 stress at BIOS −100, PL 220 W — 2026-11-08 12:53–13:09 — PASS

y-cruncher `13-HSW ~ Airi` (AVX2), config `StressTest`, LogicalCores 0–23, 16 GB, tests BKT, BBP, SFTv4, SNT, SVT, FFTv4, N63, VT3 at 120 s each (960 s), StopOnError true. Load span 12:53:02–13:09:12 (full 960 s ran), then idle until the window closed 13:12. Log `titan-sensors-bios3.csv`.

| 2-min window | Pkg W (avg) | Vcore avg | P-core clock avg | Core max °C | VR current max | PL flag |
|---|---|---|---|---|---|---|
| 12:53–12:55 | 181 | 1.239 | 5287 | 85 | 154 A | 0% |
| 12:55–12:57 | 219 | 1.220 | 5221 | 95 | 188 A | 98% |
| 12:57–12:59 | 216 | 1.178 | 5021 | 95 | 197 A | 97% |
| 12:59–13:01 | 217 | 1.236 | 5275 | 91 | 191 A | 3% |
| 13:01–13:03 | 220 | 1.173 | 4991 | 92 | 199 A | 97% |
| 13:03–13:05 | 144 | 1.277 | 5272 | 91 | 189 A | 5% |
| 13:05–13:07 | 211 | 1.238 | 5287 | 91 | 180 A | 0% |
| 13:07–13:09 | 215 | 1.217 | 5202 | 92 | 194 A | 92% |

- Thermal-throttle / PROCHOT samples: **0 of 483** loaded samples. Peak core 95 °C.
- WHEA-Logger events since 12:52: **none**. No crash, run completed.
- Heaviest tests drew up to ~199 A and pulled clocks to 4.89–5.0 GHz under the 220 W cap — expected; the cap is doing its job.
- Conclusion: −100 mV is stable for heavy all-core AVX2 at 220 W. Fable's AVX2 gap closed.

## Run 10: BIOS −100, PL1 = PL2 = 220 W — 2026-11-08 12:40–12:50 — CLEAN

Log `titan-sensors-bios3.csv`, window 12:40:32–12:50:14, new fan profile.

| Metric | Run 10 (220 W) | Run 9 (215 W) |
| --- | --- | --- |
| Score | **28,927** | 28,527 |
| Package power avg / max | 214.8 / 220.2 W | 211.5 / 215.3 W |
| PL limit flag | **15 %** (limit barely binding) | 99.7 % |
| Vcore avg | 1.230 V | 1.226 V |
| P-core 0 / ring avg | **5.29** / 4.48 GHz | 5.22 / 4.47 GHz |
| Package temp avg / max | 90.7 / **93 °C** | 89.7 / 93 °C |
| Thermal flags | **0** | 0 |

P-cores sit at the 53x ceiling almost all run; at −100 the chip only wants ~215–220 W, so a higher PL buys nothing. **CEP check:** P-core T0 effective clock is 0.8–1.6 % below core clock, same as stock Run 1 (0.7–1.6 %), so no CEP clock stretching at −100. **Chosen all-core limit: PL1 = PL2 = 220 W** (hottest core 93 °C, ~3 °C margin to target).

## Review: "−80 offset + lower AC LL" idea (independent Fable review, 2026-11-08)

Verdict: neutral to worse with current data. Effective cut ≈ offset + (1.1 − AC) × I (I = CPU's internal estimate; ±10 %). −80/AC 0.9 → single −88, R23 −115, heavy AVX2 ≈ −124; −80/AC 0.5 → −104 / −185 / −212 (past the −150 crash). Peak single-core VID is set mostly by the offset, so −80 raises it (~1.28 → ~1.30 V).

Follow-ups it recommends:
- **Single-core Vmin probe:** CoreCycler P95 SSE 1T at −120 then −140 (two rounds × 6 min or one × 10 min), check WHEA ID 19. Pass at −140 → tilt the other way (bigger offset, AC 1.1). Fail at ≤ −120 → a tilted combo (e.g. −80 / AC 0.8) becomes worth a trial.
- **CEP detection** for any AC LL cut: HWiNFO Effective Clock vs Core Clock, plus score vs baseline.
- **Heavy all-core AVX2 test at −100** (y-cruncher or P95 Small FFT AVX2, ~15 min, ~220 A): never run, highest-current case.
- **Voltage cap:** 1.40 V binds all-core because pre-droop VID ≈ 1.43 V at ~175 A with AC 1.1; use ~1.45 V or drop it.
- Final PL in BIOS, not ThrottleStop.

## Run 9: BIOS −100, PL1 = PL2 = 215 W, new fan profile — 2026-11-08 12:27–12:38 — CLEAN

Log `titan-sensors-bios3.csv`, window 12:28:13–12:38:05. FanControl profile with fans to max above 80 °C (standard from now on).

| Metric | Run 9 (215 W) |
| --- | --- |
| Score | 28,527 |
| Package power avg / max | 211.5 / 215.3 W |
| Vcore avg | 1.226 V |
| P-core 0 / E-core 8 / ring avg | 5.22 / 4.00 / 4.47 GHz |
| Package temp avg / max | 89.7 / **93 °C** |
| Hottest cores max | P2, P7 92 °C |
| Flags | PL limit 99.7 %, **zero thermal flags** |

Clean at 215 W with 3–4 °C margin to the ~96 °C target. Score is ~1 % below Run 8 despite more power; ring averaged 4.47 GHz (Run 8: 4.62) — ring clock varies run to run, watch it. Next: 220 W.

## Run 8: BIOS −100, ThrottleStop PL1 = PL2 = 210 W — 2026-11-08 12:10–12:20

ThrottleStop TPL (MSR, Lock off, Sync MMIO off; MMIO unreadable). Log `titan-sensors-bios2.csv`, window 12:10:36–12:20:16. Limit held (package max 210.2 W).

| Metric | Run 8 (210 W) | Run 6 (no PL, 3 min) |
| --- | --- | --- |
| Score | **28,823** | 28,854 |
| Package power avg / max | 206.9 / 210.2 W | 217 / 225 W |
| Vcore avg | 1.211 V | 1.233 V |
| P-core 0 / E-core 8 / ring avg | 5.21 / 3.98 / 4.62 GHz | 5.29 / 3.95 / 4.41 GHz |
| Package temp avg / max | 92.4 / 97 °C | 94.2 / 98 °C |
| Hottest cores max | P2, P4, P5, P7 96 °C | — |
| Flags | PL limit 99.7 %, **thermal 2.1 %** (6 samples, 12:13:55–12:15:47, package 92–97 °C) | thermal 7.8 % |

**Fan profile changed mid-run:** at 12:16 the user switched FanControl to a profile that goes to max above 80 °C; System 2 fan 636 → 1,700 RPM (CPU fan was already at max ~1,930 RPM in all runs). Package temp fell 94 → 90 °C at the same 207 W and the thermal flags (all 12:13–12:15) stopped. Run 8 mixes two fan profiles; Runs 1–8 used the old profile (System 2 ~636 RPM). **New profile is the standard from Run 9.** Case airflow is worth ~4–5 °C at ~207 W. Next: 215 W.

## Run 7: −150.4 mV (ThrottleStop over BIOS −100) — 2026-11-08 12:01 — FAIL

Core + P Cache −150.4 mV (250 mV range), E Cache 0, VR Voltage Limit Auto. Cinebench R23 crashed after **32 s** (12:01:08–12:01:40) with no score: `ACCESS_VIOLATION (0xC0000005)` in Cinebench's own crash report (`%APPDATA%\Maxon\…\_bugreports\_BugReport.txt`, `minidump.dmp`). No Windows crash. A random access violation under an all-core load is a typical undervolt calculation error. **−150 is unstable even at all-core** (where the voltage margin is largest), so it would fail single-core too. Usable range is −100 (validated) to somewhere below −150; −125 untested.

## Run 6: BIOS −100 mV, VR Voltage Limit Auto — 2026-11-08 11:54–11:58 (3 min)

Same as Run 5 but CPU VR Voltage Limit back to Auto. Log `devices/private/titan-sensors-bios2.csv`, window 11:55:06–11:58:06.

| Metric | Run 6 | Run 5 (1.40 V cap) |
| --- | --- | --- |
| Score (3 min vs 10 min) | 28,854 | 28,197 |
| Package power avg / max | 217 / 225 W | 188 / 195 W |
| Vcore avg | 1.233 V | 1.179 V |
| P-core 0 / E-core 8 / ring avg | 5.29 / 3.95 / 4.41 GHz | 5.07 / 3.95 / 4.46 GHz |
| Package temp avg / max | 94.2 / 98 °C | 87.2 / 90 °C |
| Flags | thermal 7.8 %, max turbo 100 %, **no EDP** | EDP/Other 100 % |

**Conclusion: the 1.40 V CPU VR Voltage Limit caused the Run 5 EDP/Other limit** (PCU enforces predicted VID incl. AC LL 1.1 mΩ × current). Re-introduce a voltage cap only after lowering AC LL, and re-check for EDP flags. Ring averaged 4.41 GHz vs 4.69 GHz in Run 3 (ThrottleStop) — unexplained, watch it.

## Run 5: BIOS −100 mV (visit 1 settings) — 2026-11-08 11:33–11:43

BIOS visit 1 (Adaptive + Offset −0.100 V, IccMax 307 A, CPU VR Voltage Limit 1.400 V, IA CEP En, UVP Dis, Enhanced Turbo Auto), no ThrottleStop offset. Log `devices/private/titan-sensors-bios1.csv`, window 11:33:54–11:43:53.

| Metric | Run 5 (BIOS −100) | Run 3 (ThrottleStop −100.6) |
| --- | --- | --- |
| Score | **28,197** (−2.9 %) | 29,046 |
| Package power avg / max | **188 / 195 W** | 221 / 227 W |
| Vcore avg / max | 1.179 / 1.248 V | 1.234 / 1.268 V |
| Core VID max | 1.259 V | 1.286 V |
| Uncore VID avg | 1.109 V | 1.163 V |
| P-core 0 / ring avg | 5.07 / 4.46 GHz | 5.28 / 4.69 GHz |
| VR current avg / max | 157 / 168 A | 178 / 186 A |
| Package temp avg / max | **87.2 / 90 °C** | 98.5 / 100 °C |
| Flags | **IA: EDP/Other (ICCmax PL4 SVID DDR RAPL) 100 %**, max turbo 100 %; **no thermal throttling** | Thermal 93.8 % |

A new limiter (EDP/Other) caps it at ~188 W, well below PL 253 W and below the thermal limit. Suspects: the new **CPU VR Voltage Limit 1.40 V** (the PCU limits frequency so predicted VID incl. AC LL × current stays under the cap) or **IccMax 307 A** (the CPU's internal current estimate, not SVID IOUT). Idle check before the run: VID at 5.3 GHz −83 mV vs stock.

## BIOS plan (to apply after CoreCycler) — drafted 2026-11-08

Walk through this with the user at BIOS time. Change one group per reboot; verify each in Windows before the next.

**Correction (after Run 7):** AC LL and the offset both set die voltage at a given current; AC LL only shapes it (more cut at high current). All-core already fails at −150 effective, so AC LL has little room: at most ~0.9 mΩ, optional, after the power-limit sweep. Order now: (1) power-limit sweep in ThrottleStop TPL at −100, (2) optional AC 0.9 / DC 1.1 BIOS step + CoreCycler, (3) voltage cap deferred until the Enhanced Turbo / 54x test (with AC LL ~1.1 a 1.40 V cap bites all-core, see Run 5).

**Why (original reasoning, partly superseded):** under Intel Default Settings the IA AC/DC load line is **1.1 / 1.1 mΩ** (Intel spec, conservative). The CPU adds `AC LL × current` to its VID request: ~28–55 mV at single-core (25–50 A), ~198 mV in Cinebench (~180 A). An adaptive offset cuts the same amount at every load (including single-core boost, the degradation-relevant voltage); a lower AC LL cuts mostly at high current (all-core). Use both, each for what it is good at.

| Step | BIOS location | Setting | Value | Notes |
| --- | --- | --- | --- | --- |
| 1 | OC → Advanced CPU Configuration | CPU Lite Load Control | **Advanced** | Lets AC and DC be set separately. "Normal" modes change DC LL too, which breaks power readings (citay). |
| 2 | same | CPU AC Loadline | **0.90 mΩ (field value 90, confirm units)**, NOT 0.50 | **Corrected after Run 7:** lowering AC LL by Δ cuts Vcore by Δ × I, the same as an offset at that current. 0.50 would be ≈ −108 mV extra at 180 A (≈ −208 mV effective all-core), far past Run 7, which crashed at −150. 0.90 ≈ −36 mV at 180 A, −8 mV at 40 A: a few watts, optional. |
| 3 | same | CPU DC Loadline | **1.10 mΩ** (unchanged) | Must match LLC Auto so VID ≈ Vcore and package power reads correctly (power limits depend on it). Check under load: HWiNFO VID vs Vcore near-identical. |
| 4 | OC → DigitALL Power | CPU Loadline Calibration Control | **Auto** | Keep. Stronger LLC raises load voltage and overshoot (against "no overvolt"); citay measured LLC Auto + lower AC LL as lowest power. |
| 5 | OC → CPU Core Voltage Mode | Adaptive + Offset | **−0.100 V** (validated: Runs 3–6, CoreCycler 16/16; −150 failed in Run 7) | Protects single-core voltage. If using the offset alone (AC LL left at 1.1), use the CoreCycler-stable value minus ~10 mV of margin (e.g. −90 if −100 passes). |
| 6 | OC → Advanced CPU Configuration | IA CEP Support | **Enabled** (keep) | Disable only if the score drops when lowering AC LL/offset (CEP stretching clocks). Citay: safe to disable on current microcode. |
| 7 | same | Long / Short Duration Power Limit | highest value with **zero thermal-throttle flags** in 10-min R23 (aim hottest core ≤ ~96 °C) | Start ~215 W, ±5 W steps. User rejected the mid-80s °C target. Re-test after any AC LL/offset change; a deeper undervolt allows a higher limit. |
| 8 | same | CPU Current Limit (IccMax) | **307 A** | Intel/citay recommendation for limits in the low 200 W range. |
| 9 | same | CPU VR Voltage Limit | **~1.40–1.45 V** (decide from CoreCycler single-core peak VID) | Hard cap against single-core overvolt. |
| 10 | (optional, last) | P-core ratios, or MSI **Enhanced Turbo** = Enabled (MCE-style: all-core ratio toward the single-core max) | stock 54x/53x; keep only if it holds with no throttle flags, VID stays under the 1.40 V cap, and the score actually rises | Per user goal. User briefly enabled Enhanced Turbo in visit 1; reverted to Auto for the baseline, test it on its own here. |

**E-cache test (before BIOS):** P/E cores, P cache (ring) and E cache share one rail (Vcore = highest request; all per-core VIDs read identical in HWiNFO). Core + P Cache were offset, E Cache was not. After CoreCycler, set CPU E Cache to −100 mV and re-run R23 10 min: P-cores already sit at 53x, so lower VID/Vcore/power at the same clock means E cache was holding the rail up. If it helps, stability-test it too. The BIOS adaptive offset covers the whole rail anyway.

**Testable live in ThrottleStop (no reboot):** voltage offset (FIVR), PL1/PL2 (TPL window; needs the MSR/MMIO power-limit lock off), IccMax (FIVR), P-core turbo ratios (FIVR Turbo Groups). **BIOS only:** AC/DC load line, LLC, IA CEP, CPU VR Voltage Limit. Do the power-limit and ratio sweeps in ThrottleStop first, then apply everything in the BIOS.

**Sequencing (agreed 2026-11-08):** BIOS visit 1 after CoreCycler = safety settings only (IccMax 307 A, CPU VR Voltage Limit ~1.40 V, LLC Auto, IA CEP En, CPU Under Voltage Protection **Dis** — must stay off or ThrottleStop offsets are blocked; AC/DC LL left at 1.1/1.1). Then test −150 mV in ThrottleStop. AC LL changes come later: offset and AC LL **stack** (−150 offset + AC 0.5 ≈ −258 mV at 180 A), whereas a ThrottleStop offset **replaces** a BIOS offset (same register). If −150 drops the R23 score, that is IA CEP; the fix is IA CEP Disabled (BIOS).

Simpler fallback if the AC LL route is fiddly: AC/DC 1.1/1.1, adaptive offset only (CoreCycler-stable − ~10 mV), power limit as step 7.

Validation after each BIOS change: Cinebench R23 10 min (score, throttle flags, VID vs Vcore) → CoreCycler pass (single-core) → save `.ocb` profile.

## Run 3: −100.6 mV offset (ThrottleStop, Core + P Cache) — 2026-11-08 09:19–09:29

Cinebench R23 multi, 10 min. Window analysed 09:20:04–09:29:40. No crash.

| Metric | Run 3 (−100.6 mV) | Run 2 (−50.8 mV) | Run 1 (stock) |
| --- | --- | --- | --- |
| Score | **29,046** (+4.0 % vs stock) | 28,617 | 27,938 |
| Package power avg / max | 221 / 227 W | 226 / 248 W | 230 / 253 W |
| Vcore avg / max | 1.234 / 1.268 V | 1.252 / 1.330 V | 1.277 / 1.394 V |
| Core VID max | 1.286 V | 1.368 V | 1.429 V |
| P-core 0 / E-core 8 / ring avg | **5.28** / 3.98 / 4.69 GHz | 5.15 / 3.97 / 4.55 GHz | 5.01 / 3.96 / 4.38 GHz |
| Package temp avg | 98.5 °C | 99.0 °C | 99.4 °C |
| Thermal throttle flag | 93.8 % | 100 % | 100 % |

P-cores now sit at the 53x all-core ceiling (5.29 GHz max) almost all run; thermal throttling is no longer constant.

Per-core temps, Run 3 (avg / max °C): P0 91.8/96, P1 89.8/93, P2 96.8/100, P3 95.8/98, P4 97.0/100, P5 98.1/100, P6 94.1/97, P7 97.5/100; E-cluster 8–11 85.8/88, 12–15 82.7/86. P-core spread is 8.3 °C avg (P1 coolest, P5 hottest); P2/P4/P5/P7 hit Tj,max while P0/P1 never did. A Thermalright contact frame is already fitted and the TIM is PTM (phase-change pad); user suspects the PTM is not seated well. Core numbers do not map reliably to physical die position, so the spread alone cannot locate the bad spot; check the PTM imprint when the cooler is off. Re-run Run 3 after remounting to compare.

## Run 4: CoreCycler pass 1 at −100.6 mV — 2026-11-08 09:30–11:12 — PASS

Prime95 SSE, Huge FFT (8960K–32768K), 1 thread, 6 min per core, 1 iteration (16 cores ≈ 1 h 40 min). **Result: PASS — 16/16 cores, 1 iteration completed 11:12, "No core has thrown an error", "No WHEA errors were observed during the test".** Peak single-core during the pass: 5.39 GHz, VID 1.281 V, Vcore max 1.26 V, package max 82 W. Logs: `C:\Software\CoreCycler\CoreCycler-v0.11.0.3\logs\CoreCycler_2026-11-08_09-30-21_PRIME95_SSE.log` and `Prime95_2026-11-08_09-30-21_SSE_HUGE_FFT_8960K-32768K.log`. Result: pending.

## Run 2: −50.8 mV offset (ThrottleStop, Core + P Cache) — 2026-11-08 09:07–09:17

Cinebench R23 multi, 10 min. Window analysed 09:07:57–09:17:42.

| Metric | Run 2 (−50.8 mV) | Run 1 (stock) |
| --- | --- | --- |
| Score | **28,617** (+2.4 %) | 27,938 |
| Package power avg / max | 226 / 248 W | 230 / 253 W |
| Vcore avg / max | 1.252 / 1.330 V | 1.277 / 1.394 V |
| Core VID max | 1.368 V | 1.429 V |
| P-core 0 / E-core 8 / ring avg | 5.15 / 3.97 / 4.55 GHz | 5.01 / 3.96 / 4.38 GHz |
| Package temp avg | 99.0 °C | 99.4 °C |
| Flags | Thermal throttle 100 %, IA max turbo limit 100 % | Thermal 100 %, max turbo 100 %, PL2 6.9 % |

Still thermal-limited; the freed headroom went into P-core and ring clocks.

## Run 1: stock baseline (defaults + XMP, VBS off) — 2026-11-08 08:47–08:58

BIOS as transcribed above; VBS, HVCI and the hypervisor off. Cinebench R23
multi, 10-minute minimum run, HWiNFO samples 08:48–08:58:

| Metric | Run 1 (stock) | Run 0 (old OC settings, VBS on) |
| --- | --- | --- |
| **Score** | **27,938** | 25,670 |
| Package power | avg 230 W, max 253 W | avg 234 W, max 277 W |
| Vcore under load | avg 1.277 V, max 1.394 V | avg 1.292 V, max 1.384 V |
| Core VID | avg 1.257 V, max **1.429 V** | avg 1.289 V, max 1.379 V |
| P-core clock (core 0) | avg 5.01 GHz | avg 4.98 GHz |
| E-core clock (core 8) | avg 3.96 GHz | avg 3.98 GHz |
| Ring | avg 4.38 GHz | avg 4.35 GHz |
| CPU package temperature | avg **99.4 °C**, max 100 °C | avg 99.2 °C, max 100 °C |
| VR current | avg 179 A, max 202 A | avg 175 A, max 203 A |
| Limit flags | thermal 100 %, max turbo 100 %, PL2 7 %, EDP 1 % | thermal 100 %, EDP 21 %, max turbo 13 %, PL2 4 % |

**Reading:** stock is still **thermally limited** for the whole run: 100 °C
at about 230 W and 1.28 V under load. Run 1 scores 8.8 % above Run 0. The
two runs differ in BIOS settings *and* VBS, so the gain can't be split
between them. Run 0's max package power of 277 W is above 253 W, which
suggests the old settings raised the power limits.

## Run 0: earlier BIOS OC settings (not stock) — 2026-11-08 08:14–08:25

**Not a stock baseline.** The BIOS still had earlier, unrecorded OC changes
during this run. It is kept as a reference only; the stock baseline is re-run
after loading BIOS defaults with XMP only.

IPDT 4.5: **all tests passed** (cache, IMC, SSE–AVX2, FMA3, prime, FP, DGEMM).

Cinebench R23 multi, 10-minute minimum run, HWiNFO samples 08:15–08:25:

| Metric | Value |
| --- | --- |
| **Score** | **25,670** |
| Package power | avg 234 W, max 277 W |
| Vcore under load | avg 1.292 V, max 1.384 V |
| P-core clock (core 0) | avg 4.98 GHz |
| E-core clock (core 8) | avg 3.98 GHz |
| Ring | avg 4.35 GHz |
| CPU package temperature | avg **99.2 °C**, max 100 °C |
| VR current | avg 175 A, max 203 A |
| CPU fan | ~1,930 RPM |

Limit flags (share of samples): **thermal throttling 100 %**, IA thermal
event 99 %, EDP/ICCmax 21 %, max turbo limit 13 %, PL2 4 %.

**Reading:** the CPU is **thermally limited**, not power limited. It sits at
Tj,max for the whole run and drops to about 5.0 GHz P / 4.0 GHz E. Any voltage
reduction should turn directly into higher sustained clocks and score.

## Change log

| When | Change | Undo |
| --- | --- | --- |
| 2026-11-08 08:2x | Disabled VBS (`DeviceGuard\EnableVirtualizationBasedSecurity=0`), Memory Integrity (`Scenarios\HypervisorEnforcedCodeIntegrity\Enabled=0`) and hypervisor launch (`bcdedit /set {current} hypervisorlaunchtype off`) so ThrottleStop can write voltage offsets. Docker Desktop (WSL2) will not start while this is in effect. | See below |
| 2026-11-08 ~08:30 | BIOS: Load Optimized Defaults, XMP Profile 1, CPU Cooler Tuning = Intel Default Settings (see BIOS section) | Restore `devices/private/bios-screenshots-config/*.ocb` |
| 2026-11-08 ~08:45 | After reboot VBS was still running (status 2, no services) with the hypervisor present. Also disabled Windows Hello Enhanced Sign-in Security (`Scenarios\WindowsHello\Enabled=0`; no biometric device is attached) and VSM launch (`bcdedit /set {current} vsmlaunchtype off`). | See below |
| 2026-11-08 09:04 | ThrottleStop FIVR: CPU Core and CPU P Cache offset −25.4 mV (Adaptive), "Do not save voltages" (resets on reboot). | FIVR → Zero Offset, or reboot |
| 2026-11-08 09:06 | ThrottleStop FIVR: Core + P Cache −50.8 mV (Run 2). | Zero Offset or reboot |
| 2026-11-08 09:19 | ThrottleStop FIVR: Core + P Cache −100.6 mV (Run 3, Run 4 CoreCycler). Still active. | Zero Offset or reboot |
| 2026-11-08 09:30 | CoreCycler `config.ini`: `maxIterations` 10000→1, `enableUpdateCheck` 1→0, `useWindowsEventLog` 1→0. Original saved as `config.ini.orig`. | Copy `config.ini.orig` back |
| 2026-11-08 11:18 | BIOS visit 1 (`devices/private/OC-Just-Minus-100.ocb`, `round1.jpg`): VR Voltage Limit 1.400 V, CPU Core Voltage Mode Adaptive + Offset, offset − 0.100 V, Speed Shift Enabled, Long Duration Maintained 128 s, CPU Current Limit 307 A, CPU Under Voltage Protection Disabled, IA CEP Enabled. **Enhanced Turbo Auto→Enabled (not planned; asked user to revert to Auto for the Run 5 baseline).** No ring offset option on this BIOS. | Load `STock.ocb` or set fields back to Auto |
| 2026-11-08 10:07 | **HWiNFO CSV logging stopped** (file ends with footer); sensor data for CoreCycler cores 7–15 lost; CoreCycler result unaffected. New log per BIOS state from now: `titan-sensors-bios1.csv`. | — |
| 2026-11-08 11:51 | BIOS: VR Voltage Limit and CPU VR Voltage Limit 1.400 → Auto (isolating the Run 5 EDP/Other limiter). ThrottleStop FIVR read back Core −0.0996 / P Cache −0.0996 from the BIOS offset (covers the ring) and IA IccMax 511.75 A (BIOS "CPU Current Limit 307" is not that register). | Set 1.400 again |

Revert VBS, HVCI, Enhanced Sign-in Security and the hypervisor (then reboot):

```powershell
sudo pwsh -NoProfile -Command "Set-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity' Enabled 1; Set-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\WindowsHello' Enabled 1; Set-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard' EnableVirtualizationBasedSecurity 1; bcdedit /set '{current}' hypervisorlaunchtype auto; bcdedit /deletevalue '{current}' vsmlaunchtype"
```

## Open items

- [x] BIOS screenshots transcribed (defaults + XMP).
- [x] VBS off confirmed after reboot; ThrottleStop 9.7 FIVR offsets apply (−25 mV verified 09:05: VID −27.5 mV at 5.3 GHz, −24.9 mV at 5.4 GHz). Launch ThrottleStop with `Start-Process -Verb RunAs`; inline `sudo` leaves it hung with no window.
- [x] Re-run the stock Cinebench baseline on defaults + XMP (Run 1: 27,938).
- [x] Cooler: **DeepCool AK620** (black), dual tower, 2× 120 mm, rated 260 W; fans already at max (~1,930 RPM) in Cinebench. Tom's Hardware: an unlimited 13700K throttles on even the best air coolers; the AK620 matches the NH-D15S. ~221 W at 98.5 °C (Run 3) is a bit worse than an AK620 should manage, so the PTM/mount may cost a few °C; room ambient **~26 °C** during Runs 1–4 (a clock on the case read 31 °C, which is case air, not room). Reviews use ~22–23 °C, so ~3–4 °C penalty; Run 3 ≈ 95 °C at review ambient, a little warm for an AK620 at 221 W. Case air ~5 °C above room suggests case airflow is worth checking. Size the power limit with margin for hotter days. Plan: power limit to stop throttling, remount PTM later and compare.
- [ ] Offset sweep with CoreCycler, then translate to BIOS Lite Load / AC LL.
- [ ] Keep stock boost ratios; test single-core/gaming stability at the undervolt (CoreCycler per-core).
- [ ] Set a CPU VR voltage cap (no overvolting at single-core boost).
- [ ] Find the all-core power limit where Cinebench settles just under Tj,max (no thermal throttle flags). User rejected the MSI-forum mid-80s target: maximise clocks, the only constraint is zero throttle flags over 10 min (aim peak core ≤ ~96 °C for a few °C of ambient margin).
- [x] Re-enabled VBS, HVCI, Enhanced Sign-in Security and the hypervisor 2026-11-09 04:3x (revert command above; `vsmlaunchtype` removed). Takes effect after the next reboot; confirm with `msinfo32` (VBS Running) and Docker/WSL2 start. ThrottleStop voltage offsets stop working from then on — BIOS settings are unaffected.
