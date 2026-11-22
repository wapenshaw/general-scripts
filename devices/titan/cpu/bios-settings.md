# BIOS settings: defaults + XMP — 2026-11-08 08:30–08:33

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

## OC (main page)

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

## DRAM

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

## Voltages

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

## Other settings (OC page)

| Setting | Value |
| --- | --- |
| Memory OC Retry Count | 2 |
| CPU Memory Changed Detect | Enabled |
| OC Quick View Timer | 3 Sec |

## DigitALL Power

All **Auto**: CPU Loadline Calibration Control, CPU Loadline Saturation
Control, CPU Over Voltage Protection, CPU Over Current Protection, CPU
Switching Frequency, CPU VRM Over Temperature Protection, CPU GT Loadline
Calibration Control, CPU GT Over Voltage Protection, CPU GT Over Current
Protection, CPU GT Switching Frequency, CPU GT VRM Over Temperature
Protection, CPU AUX Loadline Calibration Control.

## Advanced CPU Configuration

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

## BIOS plan (to apply after CoreCycler) — drafted 2026-11-08

Walk through this with the user at BIOS time. Change one group per reboot; verify each in Windows before the next.

**Correction (after [Run 7](runs.md)):** AC LL and the offset both set die voltage at a given current; AC LL only shapes it (more cut at high current). All-core already fails at −150 effective, so AC LL has little room: at most ~0.9 mΩ, optional, after the power-limit sweep. Order now: (1) power-limit sweep in ThrottleStop TPL at −100, (2) optional AC 0.9 / DC 1.1 BIOS step + CoreCycler, (3) voltage cap deferred until the Enhanced Turbo / 54x test (with AC LL ~1.1 a 1.40 V cap bites all-core, see [Run 5](runs.md)).

**Why (original reasoning, partly superseded):** under Intel Default Settings the IA AC/DC load line is **1.1 / 1.1 mΩ** (Intel spec, conservative). The CPU adds `AC LL × current` to its VID request: ~28–55 mV at single-core (25–50 A), ~198 mV in Cinebench (~180 A). An adaptive offset cuts the same amount at every load (including single-core boost, the degradation-relevant voltage); a lower AC LL cuts mostly at high current (all-core). Use both, each for what it is good at.

| Step | BIOS location | Setting | Value | Notes |
| --- | --- | --- | --- | --- |
| 1 | OC → Advanced CPU Configuration | CPU Lite Load Control | **Advanced** | Lets AC and DC be set separately. "Normal" modes change DC LL too, which breaks power readings (citay). |
| 2 | same | CPU AC Loadline | **0.90 mΩ (field value 90, confirm units)**, NOT 0.50 | **Corrected after [Run 7](runs.md):** lowering AC LL by Δ cuts Vcore by Δ × I, the same as an offset at that current. 0.50 would be ≈ −108 mV extra at 180 A (≈ −208 mV effective all-core), far past [Run 7](runs.md), which crashed at −150. 0.90 ≈ −36 mV at 180 A, −8 mV at 40 A: a few watts, optional. |
| 3 | same | CPU DC Loadline | **1.10 mΩ** (unchanged) | Must match LLC Auto so VID ≈ Vcore and package power reads correctly (power limits depend on it). Check under load: HWiNFO VID vs Vcore near-identical. |
| 4 | OC → DigitALL Power | CPU Loadline Calibration Control | **Auto** | Keep. Stronger LLC raises load voltage and overshoot (against "no overvolt"); citay measured LLC Auto + lower AC LL as lowest power. |
| 5 | OC → CPU Core Voltage Mode | Adaptive + Offset | **−0.100 V** (validated: [Runs 3–6](runs.md), CoreCycler 16/16; −150 failed in [Run 7](runs.md)) | Protects single-core voltage. If using the offset alone (AC LL left at 1.1), use the CoreCycler-stable value minus ~10 mV of margin (e.g. −90 if −100 passes). |
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

