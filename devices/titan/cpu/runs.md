# Run 20: CoreCycler P-cores 4–5 (preferred), 15 min each, P +2 / E +2 — 2026-11-09 01:33–02:04 — PASS

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

BIOS [as transcribed above](bios-settings.md); VBS, HVCI and the hypervisor off. Cinebench R23
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

