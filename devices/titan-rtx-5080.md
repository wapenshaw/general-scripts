# TITAN: RTX 5080 tuning (mVolt+ and MSI Afterburner)

Last inspected: **2026-11-04**. Times below use **Asia/Kolkata (IST, UTC+05:30)**.
Host details are in [titan.md](titan.md).

## Device

| Item | Value |
| --- | --- |
| GPU | NVIDIA GeForce RTX 5080 (Blackwell) |
| PCI ID | `VEN_10DE&DEV_2C02&SUBSYS_41961458` (subsystem vendor `1458` = Gigabyte), bus `00000000:01:00.0` |
| VBIOS | `98.03.3b.40.11` |
| Driver at inspection | **621.01** |
| mVolt+ adapter ID | `pci-2c0210de-41961458-00002c02-b01-s00` (only adapter mVolt+ lists; the UHD 770 iGPU is not shown) |
| Power limit | 360 W default (100 %), range 69–111 %, max 400 W |
| Core rail (NVVDD) | 800–1040 mV operating range; device range 445–1280 mV in 5 mV steps |
| Fabric rail (MSVDD) | 800–990 mV operating range; device range 445–1280 mV |
| OCP limits | NVVDD 300 A, MSVDD 120 A (both at default and at max) |
| Clock offset limits | Core −1000/+1000 MHz, memory −1000/+3000 MHz, XBAR/SYS/Video ±1000 MHz |
| Fans | 3 fans, 1200–3000 RPM (30–100 %), zero-RPM at idle |

## Tools installed

| Tool | Version | Location | Starts how |
| --- | --- | --- | --- |
| [mVolt+](https://github.com/b00nz/mVolt) | 0.50.11 | `C:\Software\mVolt+.exe` (portable exe, no installer) | Manually. "Start with Windows" **not** enabled |
| MSI Afterburner | 4.6.7.17352 | `C:\Program Files (x86)\MSI Afterburner\` | Scheduled task `\MSIAfterburner`, logon trigger, `RunLevel=Highest`, runs `MSIAfterburner.exe /s` |
| RivaTuner Statistics Server | (bundled with Afterburner) | `C:\Program Files (x86)\RivaTuner Statistics Server\` | Launched by Afterburner |

mVolt+ data folder: `%LOCALAPPDATA%\mVolt+\`: `startup.log`,
`appearance.json`, `last-adapter.txt`, and a per-GPU settings file under
`profiles\` (format `mvolt.profile.v3`, which holds both UI settings and saved
profiles; `.bak` beside it). The startup log shows the CLI runs from an elevated shell and
the GUI relaunches itself elevated when started normally.

## State at inspection — 2026-11-04 ~16:50

### Applied to the GPU (read with `mVolt+.exe --status`)

| Setting | Value |
| --- | --- |
| mVolt+ active profile | none |
| Power limit | 100 % (360 W requested and enforced); no watt cap |
| Core / memory offset | 0 / 0 MHz (global offset as mVolt+ reads it) |
| NVVDD offsets (VMIN, REL, ALT, OV) | 0, 0, 0, 0 |
| MSVDD offsets (VMIN, REL, ALT, OV) | 0, **−50 mV**, 0, 0 |
| Voltage boost / XOC / boost lock | 0 % / off / off |
| Clock range lock | not locked (0–3090 MHz) |
| Thermal input overrides | none (channels 0–5 not overridden) |
| Fans | automatic |

The **MSVDD REL −50 mV** offset was set before mVolt+ was installed. The most
likely source is NVIDIA's driver: since driver 572.60, NVIDIA has applied a
default −50 mV MSVDD offset on RTX 50 cards to fix launch black screens. That
was reported for the 5090 and is unconfirmed for this 5080. Afterburner cannot
write the MSVDD rail. Leave it as is unless testing shows a reason to change it.

### Afterburner profile (applied at every logon until it was reset at 16:57; see the change log)

Afterburner applies the `[Startup]` section of
`Profiles\VEN_10DE&DEV_2C02&SUBSYS_41961458&REV_A1&BUS_1&DEV_0&FN_0.cfg`
when its logon task runs. It also re-applies after sleep
(`RestoreAfterSuspendedMode=1`). Low-level interface and voltage control are
unlocked.

| Section | Power limit | Memory | Core |
| --- | --- | --- | --- |
| `Startup` (applied at logon) | 100 % | +0 | Curve undervolt (below) |
| `Profile1` (hotkey slot 1) | 111 % | +3000 MHz (Afterburner units) | Same curve |
| `Profile5` (hotkey slot 5) | 111 % | +3000 MHz | Same curve |

**Decoded startup V/F curve:** points from 810 to 895 mV are raised by
+468 MHz (810 mV → 2475 MHz, 850 mV → 2692 MHz, 895 mV → 2880 MHz). Every point
from **900 mV upward is capped at 2880 MHz**. In effect, the card runs at
**2880 MHz at about 895 mV** and never asks for more voltage. This is the usual
"flatten the curve" undervolt. The stock curve reaches 4297 MHz at the top
points, which is a placeholder value, not a usable clock.

`CoreClkBoost=-502296` in the file is in kHz (−502 MHz). It is the global
offset Afterburner used to flatten the curve, but mVolt+ reports the core
offset as 0, so the two tools read this setting differently. Afterburner fan
control is in auto mode (`FanMode=1`, software fan curve off).

## Factory BIOS limits (mVolt+ BIOS override window, 2026-11-04)

Read from **Settings → Advanced tuning → BIOS override** (method **Direct**,
driver 621.01, VBIOS `98.03.3b.40.11`) **before any override was saved**.
These are the values to return to. "Original limits" or "Remove BIOS
override" in that window restores them, and so does
`mVolt+.exe --remove-bios-override` followed by a Windows restart.

**Clocks** (offset ranges, MHz)

| Domain | BIOS default | Active range | Theoretical max |
| --- | --- | --- | --- |
| Core | −1000 … +1000 | −1000 … +1000 | — |
| Memory | −1000 … **+3000** | −1000 … +3000 | **+4999** |
| XBAR | −1000 … +1000 | −1000 … +1000 | — |
| SYS | −1000 … +1000 | −1000 … +1000 | — |
| Video | −1000 … +1000 | −1000 … +1000 | — |

The core *clock range* ceiling (3090 MHz, `--clock-range`) is not on this tab.

**Power & current**

| Limit | Default | Active at inspection | Theoretical max |
| --- | --- | --- | --- |
| Power limit | **360 W** | 400 W (the CLI had set 111 %) | 9999 W |
| Board input current limit | **40 A** | 40 A | — |
| NVVDD (core rail) current limit | **300 A** | 300 A | — |
| MSVDD (memory-subsystem rail) current limit | **120 A** | 120 A | — |

**Voltage**

| Setting | Default | Active at inspection | Theoretical max |
| --- | --- | --- | --- |
| NVVDD REL | 1040 mV | 1040 mV | 1200 mV |
| NVVDD ALT/OP | 1060 mV | 1060 mV | 1200 mV |
| NVVDD OV | 1200 mV | 1200 mV | 1280 mV |
| NVVDD VMIN | 800 mV | 800 mV | — |
| MSVDD REL | 995 mV (→ **945 mV** effective with Black-screen fix) | 995 mV | 1200 mV |
| MSVDD ALT/OP | **1015 mV** | **1060 mV** (differs from default; cause unknown, possibly driver-managed) | 1200 mV |
| MSVDD OV | 1200 mV | 1200 mV | 1280 mV |
| MSVDD VMIN | 800 mV | 800 mV | — |
| Black-screen fix | **On** (the driver's −50 mV MSVDD REL) | On | — |
| Voltage offsets (experimental) | **Off** | Off | — |
| **Speedo** | **2208** | 2208 | 2287.03 |

**Speedo** is the chip's factory silicon-quality value, and the driver builds
the V/F curve from it. **Never change it.**

**What limits this card (from testing):** under the daily tune, the `0x4`
power-cap flag stays active at about 372 W, well below the 400 W limit, while
the clock sits at about 3045 MHz instead of the 3090 cap. The **NVVDD 300 A
current limit** is the likely cause. At about 0.92–0.95 V that's about
276–285 W on the core rail alone, which fits power tracking voltage at a fixed
W/mV ratio. It's inferred and not yet proven; raising NVVDD current is the test.

## Current best tune (2026-11-04)

Applied with
[`Set-GpuUndervolt.ps1`](../powershell/rtx-5080/Set-GpuUndervolt.ps1)
(stock limits only, **no BIOS override**). Measured in a Steel Nomad loop over
140 s:

| Setting | Stock | Old Afterburner undervolt | **Daily tune** | Faster (soak test pending) |
| --- | --- | --- | --- | --- |
| Core offset / cap | 0 / none | +468 / 2880 | **+450 / 3090** | +450 / 3090 |
| Memory | +0 | +0 | **+3000** | +3000 |
| Power limit | 100 % | 100 % | **111 %** | 111 % |
| XBAR offset | 0 | 0 | **+400** | +500 |
| FPS / 1 % low | 84.2 / 71.3 | 86.8 / 66.1 | **97.0 / 83.4** (+15 % / +17 %) | 98.0 / 84.4 (+16 % / +18 %) |
| Core clock / voltage | 2763 MHz / about 995 mV | 2856 / about 890 mV | **3049 / about 945 mV** | 3047 / about 945 mV |
| Power / temperature | 359 W / 73 °C | 306 W / 68 °C | 374 W / 72 °C | 375 W / 73 °C |

The **daily tune keeps XBAR at +400**, two steps below the point where +700
crashed the whole system. +500 is about 1 % faster. Make it the default only
after a long soak test (an hour of Steel Nomad loop plus real games) with no
crash, artifacts or grey screens. Settings last until reboot. Saving them as an
mVolt+ startup profile is still to do.

## Before/after: stock vs undervolt — 2026-11-04

**Load:** custom 3DMark Steel Nomad loop, running the whole time. The undervolt
was applied live between the two runs.
**Method:** [`Measure-GpuLoad.ps1`](../powershell/rtx-5080/Measure-GpuLoad.ps1),
180 one-second `nvidia-smi` samples per run, with the first 20 s excluded.
The raw CSVs were not kept; the table below is the record.
`nvidia-smi` can't read core voltage on driver 621.01, so the expected voltage
(about 895 mV) is not a measured value.

| | Stock (17:03–17:06) | Undervolt (17:06–17:09) | Change |
| --- | --- | --- | --- |
| Settings | mVolt+ core 0, no clock lock, 100 % power | `--core 468 --clock-range 0,2880`, 100 % power | — |
| Core clock avg (min–max) | **2765 MHz** (2730–2790) | **2855 MHz** (2850–2865) | **+90 MHz (+3.3 %)**, steadier |
| Board power avg (min–max) | **357.9 W** (351.2–364.4) | **307.7 W** (296.7–319.6) | **−50 W (−14 %)** |
| GPU temperature avg | 74.0 °C | 68.3 °C | −5.7 °C |
| Fan avg | 77.2 % | 74.9 % | −2.3 points |
| Memory clock | 15001 MHz | 15001 MHz | — |
| GPU utilisation | 100 % | 100 % | — |
| Throttle reason | `0x4` (SW power cap), every sample | `0x4`, every sample | see note |

**Reading the results:**

- At stock the card hits its 360 W limit, and clocks drop to about 2765 MHz to
  stay within it.
- With the undervolt, the card runs faster at about 50 W less.
- The capped clock is 2880 MHz, but under load the card held about 2855 MHz.
  Blackwell lowers the curve by a few bins as temperature rises, so this is
  expected. Power was well below the cap.
- `0x4` was still reported on every sample while drawing about 308 W. This is
  unexplained. It may be how the driver flags a clock-range lock.

**Not yet measured:**

- Steel Nomad **scores**. Read them from 3DMark's results.
- Long-run stability. Three minutes doesn't prove stable. Afterburner ran the
  same 2880 MHz / 895 mV point before, but run a long loop and real games
  before trusting it.

The fan reading changed less than temperature. The stock run went first, so
the fan curve was still catching up when the undervolt run started. A fairer
comparison would let the card cool between runs or swap the order.

## Running mVolt+ and Afterburner together

**Short answer: don't let both tools write to the GPU.** mVolt+'s docs don't
mention Afterburner. The risk comes from how the two tools behave:

- Both write through NVAPI. Afterburner writes its curve, power limit and memory
  offset at every logon and after every resume. Anything mVolt+ sets for the
  same controls may be overwritten silently.
- mVolt+ also has its own startup apply (a logon task, if enabled). Two startup
  tuners race each other.
- Controls only mVolt+ has (NVVDD/MSVDD rail offsets, XBAR/SYS/Video domains,
  voltage demand, watt cap, thermal inputs) don't overlap with Afterburner.
  Having Afterburner open while adjusting only those is lower risk, but it's
  still untested here.
- RTSS can keep running on its own. mVolt+ supports the RTSS overlay, and
  mVolt+ hotkeys need RTSS running.

**Plan:**

1. Keep the current Afterburner undervolt as the known-good baseline. It's
   recorded above.
2. Before tuning with mVolt+: quit Afterburner (tray → Exit) so it can't
   re-apply settings mid-test. RTSS can stay.
3. Once an mVolt+ profile matches or beats the baseline, open Afterburner
   settings and turn off **"Apply overclocking at system startup"**. Then
   disable the `\MSIAfterburner` logon task, or keep Afterburner only for
   monitoring.

## Community tips (2026-11 research)

These are anecdotes, not author documentation. Every card behaves differently.

- **Core undervolt:** a 5080 test held about 3068 MHz at 965 mV (317 W,
  74 °C) and dropped clocks at 960 mV and below
  ([gamegpu](https://en.gamegpu.com/news/zhelezo/rezultaty-andervoltinga-videokarty-geforce-rtx-5080-pri-napryazhenii-965-mv)).
  Another guide reports 2700 MHz at 900 mV saves about 90 W for roughly 0.8 %
  lower scores, and some cards need 940 mV for 2900 MHz
  ([gaming-st](https://gaming-st.com/trouble-settings/gpu-undervolt-guide/)).
  The current 2880 MHz at 895 mV is aggressive by those numbers. Keep it only
  as long as it stays stable.
- **Core offset:** Reddit and Overclockers UK reports cluster around +240 to
  +350 MHz, and most 5080s reportedly reach +300
  ([Overclockers UK](https://forums.overclockers.co.uk/posts/38139126/)).
- **Memory:** +3000 MHz (Afterburner units) is common on 5080s. Tune memory
  separately, after the core is stable.
- **MSVDD undervolt:** results on 5090s conflict. One user cut about 60 W in
  Steel Nomad and another saw no effect
  ([Hardwareluxx](https://www.hardwareluxx.de/community/posts/31249041/)).
  There's no measured benefit for a 5080 yet, so test it on this card.
- **Testing:** change one setting at a time and keep memory at stock until the
  core is stable
  ([evezone](https://evezone.evetech.co.za/build-lab/rtx-5080-undervolting-guide-cooler-quieter-step-by)).
  Run OCCT or a long game session. Short benchmarks can pass while games still
  crash. A setting the driver accepts is not proof of stability.

## XBAR (crossbar) and Reddit findings (2026-11-04)

**What XBAR is:** the crossbar clock, which moves data between the shader
clusters (GPCs) and the L2 cache and memory controllers. It runs on the
**MSVDD** rail with SYS and Video. The core runs on NVVDD. A core offset
reaches XBAR through `msvdd_clock_ratio` (0.8999 by default on this card).
Under the Steel Nomad loop, XBAR measured 2210–2365 MHz while the core ran at
2790–2865 MHz. Afterburner can't adjust XBAR; mVolt+ can (`--xbar-offset`,
`--xbar-vdemand`, `--msvdd-clock-ratio`, `--vf-curve xbar`).

**Reddit (read in a browser; these are anecdotes):**

| Card | Settings | Result | Thread |
| --- | --- | --- | --- |
| RTX 5080 (Forza Horizon 6, 4K) | XBAR 0 → +400 in +50 steps, core fixed at about 3045 MHz | **75.7 → 80.5 FPS (+6.3 %) for +9 W**. Gains taper above +250 | [r/overclocking: RTX5080 XBAR OC +400](https://www.reddit.com/r/overclocking/comments/1wlcygd/rtx5080_xbar_oc_400mhz_mvolt_0461_61692/) |
| RTX 5080 Gainward Phantom GS (Cyberpunk PT) | +220 core, +3000 memory, 111 % power, XBAR +400 | Crashes at +450. **0.1 % lows get worse as XBAR rises** | same |
| RTX 5080 MSI Ventus (water) | +285 core capped at 3100 (about 0.98 V), XBAR +400 with **ratio 1.0**, +3000 memory, 111 % power, +200 SYS | Steel Nomad about **10,200**, about 330 W gaming | [r/overclocking: XBAR UV/OC results](https://www.reddit.com/r/overclocking/comments/1w609da/xbar_uvoc_please_share_your_results_here_for/) |
| RTX 5080 Asus Prime | 0.990 V, +450 core (about 3080 MHz), XBAR +550 (about 2900 MHz), +2500 memory, 100 % power (360 W) | Steel Nomad **9,650** | same |
| RTX 5080 | Default XBAR 2430 MHz at 1.025 V | Stable at 2630 MHz at 0.900 V | same |
| RTX 5080 Astral | Memory +3000 → **+4800** (needs BIOS override) | Steel Nomad 10,380 → 10,540 | [r/RTX5080: How to use mvolt+](https://www.reddit.com/r/RTX5080/comments/1xm3p00/how_to_use_mvolt_besides_xbar_clock/) |
| RTX 5070 Ti | XBAR +250 with −25 mV | Best Cyberpunk result. **Performance regressed** at +275 and above | XBAR UV/OC results |

**Takeaways:**

- **Capping the requested clock** (`--clock-range`) is reported to undervolt
  better than a flattened curve. The card doesn't drop 1–2 voltage steps below
  the target, so only temperature-driven clock drops remain. This is the method
  `Set-GpuUndervolt.ps1` uses.
- **XBAR instability is often silent.** It shows up as lower FPS or worse lows,
  grey screens, or crashes later in long sessions. Judge each step by FPS and
  1 % lows, not just by whether it passes.
- Typical 5080 XBAR offsets are +250 to +550 MHz. The suggested target is XBAR
  "as close to 3 GHz" as the card allows. Setting `msvdd_clock_ratio` to 1.0
  raises XBAR further, with core and XBAR moving 1:1.
- The core sweet spot is around **3.00–3.08 GHz**. Above that, users report
  lower performance from memory error correction kicking in.
- Memory beyond **+3000** needs mVolt+'s **BIOS override**
  (Settings → Advanced tuning → BIOS override). That override persists across
  reboots.
- The mVolt+ developer posts on the overclock.net RTX 5090 owners thread. An
  options explainer is at about post #40,378 (page 2019).

## Warnings

- **Driver 621.01 (installed):** mVolt+'s guide says that on RTX 50 with
  driver 621.01 and later, some writes report success while the GPU keeps its
  previous limits, and voltage-limit controls need the BIOS override. Check
  `--status` after every write instead of trusting exit code 0.
- **Driver regressions:** past NVIDIA drivers broke mVolt+ power-limit writes,
  causing black screens and driver crashes
  ([Tom's Hardware](https://tomshardware.com/pc-components/gpu-drivers/nvidias-latest-driver-update-breaks-mvolt-overclocking-functionality-nifty-open-source-app-allowed-users-to-increase-the-power-limit-to-700w-on-their-rtx-50-series-gpus-without-hardware-mods)).
  GeForce 616.56 also caused regressions for overclocked RTX 50 cards
  ([FPS Review](https://www.thefpsreview.com/2026/09/01/geforce-616-56-is-the-fastest-driver-in-months-and-it-broke-two-things-on-the-way/)).
  Re-check after every driver update.
- **BIOS override:** not used. If it is ever enabled, it persists across
  reboots, and the display can blank during the GPU restart. Remove it with
  `mVolt+.exe --remove-bios-override` from an admin terminal, then restart
  Windows.
- **Power fields:** one report says some mVolt+ power-limit fields behave like
  current limits in amps
  ([Techora](https://techora.ru/news/oshibka-v-mvolt-limity-moshchnosti-rtx-2026-08-29)).
  This is a single unverified source. Don't raise OCP limits.

## Change log

| When (IST) | Change | Undo |
| --- | --- | --- |
| 2026-11-04 16:46 | Placed mVolt+ 0.50.11 at `C:\Software\mVolt+.exe` | Settings → General → Uninstall mVolt+, then delete the exe |
| 2026-11-04 16:49 | Read-only CLI checks (`--version`, `--help`, `--list-gpus`, `--status`). No GPU writes | — |
| 2026-11-04 16:51 | Opened the mVolt+ GUI. It accepted the risk prompt and created `profiles\98.03.3b.40.11-pci-2c0210de-41961458-00002c02-b01-s00.json` (settings only, no saved tuning profiles; Start with Windows off). The log shows no GPU writes | — |
| 2026-11-04 16:57 | **Reset the Afterburner GPU profile to defaults and quit Afterburner.** `[Startup]` is now power 100 %, core 0, memory 0, and no curve offsets. `Profile1`/`Profile5` still hold the old 111 % / +3000 memory values on hotkeys. The `\MSIAfterburner` logon task is still enabled, so Afterburner starts at logon but applies stock settings | Load the curve from the decoded values above, or re-save it in Afterburner |

**State after the reset (16:58, `--status`):** stock power (100 %, 360 W), core,
memory and NVVDD offsets all 0, clock range unlocked, fans automatic. MSVDD REL
is still −50 mV (probably the driver default). mVolt+ now reports
`active_profile: "Custom"` (it was `null` before the GUI was opened). That is
probably just a label for "no saved profile applied", because no writes appear
in the log.

| When (IST) | Change | Undo |
| --- | --- | --- |
| 2026-11-04 17:03 | Stock baseline logged under the Steel Nomad loop (table above) | — |
| 2026-11-04 17:06 | **Applied the undervolt:** `mVolt+.exe --gpu-id pci-2c0210de-41961458-00002c02-b01-s00 --core 468 --clock-range 0,2880` (same as `Set-GpuUndervolt.ps1`). `--status` confirmed core +468 and the clock range locked at 0–2880. This is a CLI write only: no mVolt+ profile was saved, and it will **not survive a reboot or driver reset** | `Set-GpuUndervolt.ps1 -Reset` (or `--core 0 --clock-range default`) |
| 2026-11-04 17:06 | Undervolt run logged under the same loop (table above) | — |
| 2026-11-04 17:19 | Sweep script bug (an `[ordered]` dictionary indexed by position) capped the clock at **500 MHz** for about 2 min. FPS dropped to ~25; the script caught it and restored +468/2880. Fixed in `Invoke-GpuTuneSweep.ps1` | — |
| 2026-11-04 17:21–17:29 | **Core offset sweep at the 900 mV target** (table below). **+575 (cap 3020) crashed the driver** at 17:29:19 (`nvlddmkm` event 153, Steel Nomad closed) | Restored `Set-GpuUndervolt.ps1 -CoreOffset 468 -MaxClock 2880` at 17:30 (verified) |
| 2026-11-04 ~18:38 | **BIOS override round 1 (user, GUI):** memory maximum 3000 → 4999, NVVDD current 300 → 330 A. Persists across reboots | GUI: restore factory values (section above), or `mVolt+.exe --remove-bios-override` + restart Windows |
| 2026-11-04 18:41–18:52 | Memory sweep +3000…+4500 under the override (results below the XBAR sweep). Daily tune (+3000) restored afterwards | — |
| 2026-11-04 ~19:10 | **BIOS override round 2 (user, GUI):** NVVDD current back to 300 A (330 A gained nothing). The override now changes only the memory maximum (4999). Daily tune reapplied after the GPU restart | as round 1 |

**Core offset sweep: 900 mV target, memory +0, XBAR 0, 100 % power, 90 s per step (PresentMon):**

| Offset | Cap (MHz) | FPS | 1 % low | Clock avg | Power | Result |
| --- | --- | --- | --- | --- | --- | --- |
| stock | — | 84.20 | 71.3 | 2763 (about 995 mV) | 358.8 W | baseline, power-capped |
| +468 | 2880 | 86.77 | 66.1 | 2856 | 306.0 W | old Afterburner undervolt |
| +468 | 2913 | 87.54 | 72.8 | 2878 | 311.6 W | ok |
| +500 | 2945 | 87.48 | 73.5 | 2906 | 313.2 W | ok |
| **+525** | 2970 | **88.21** | **74.5** | 2932 | 314.5 W | **best** |
| +550 | 2995 | 87.02 | 70.1 | 2949 | 310.2 W | **regressed**: higher clock, lower FPS, lows and power. Edge of stability |
| +575 | 3020 | — | — | — | — | **driver crash** |

**Memory sweep, 17:33–17:46: core +500, 900 mV target (cap 2945), 100 % power, 140 s per step:**

| Memory | FPS | 1 % low | Clock avg | Power | Live XBAR |
| --- | --- | --- | --- | --- | --- |
| +0 | 87.76 | 74.4 | 2904 | 313.8 W | 2327 |
| +1000 | 89.29 | 75.9 | 2903 | 318.3 W | 2355 |
| +2000 | 90.34 | 74.7 | 2899 | 322.1 W | 2358 |
| +2500 | 90.63 | 76.9 | 2899 | 323.0 W | 2354 |
| **+3000** | **90.98** | 76.5 | 2898 | 323.8 W | 2355 |

FPS rose at every step, +3.7 % from +0 to +3000 for +10 W, with no regression
or artifacts. +3000 is mVolt+'s limit without the BIOS override, so **memory
is fixed at +3000**. Going higher needs the override, which waits for the
user's go-ahead.

**Clock-cap sweep, 17:46–18:03: cap 3090 MHz (mVolt+ maximum), memory +3000, power 111 %, 140 s per step:**

| Core | FPS | 1 % low | Clock avg (min) | Power | Live XBAR |
| --- | --- | --- | --- | --- | --- |
| +400 | 91.07 | 78.5 | 2922 (2865) | 344.8 W | 2367 |
| +425 | 92.09 | 79.2 | 2929 (2865) | 343.4 W | 2373 |
| +450 | 92.30 | 78.5 | 2943 (2887) | 343.9 W | 2361 |
| +475 | 91.04 | 73.5 | 2962 (2895) | 343.1 W | 2377 |
| +500 | 90.96 | 73.3 | 2994 (2910) | 337.4 W | 2350 |
| +525 | 92.71 | 79.3 | 2965 (2917) | 335.8 W | 2357 |

**111 % didn't raise power draw.** mVolt+ and NVML both report 400 W
requested and enforced, yet the `0x4` power-cap flag stays active at
**330–345 W**, and the clock moves between about 2910 and 3060 MHz without
reaching the 3090 cap. Power scales with voltage at a fixed ratio
(stock: 358 W at about 995 mV; here: 337 W at about 915 mV; about 0.36 W per
mV in both). That pattern fits a **current (amps) limit**, not a board power
limit. This is inferred, not confirmed. Raising it probably needs the BIOS
override, which waits for the user's go-ahead. Under a current limit,
**lower voltage at the same clock directly buys clock speed**.

FPS differences between +400 and +525 are about ±1 FPS with no trend, so
one run per step can't rank them. **+450 is the base for XBAR testing:** it's
in the top group and leaves margin below the +525 to +575 crash zone.

**XBAR sweep, 18:04–18:20: core +450, cap 3090, memory +3000, power 111 %, 140 s per step:**

| XBAR | Live XBAR (MHz) | FPS | 1 % low | Core clock avg (min) | Power |
| --- | --- | --- | --- | --- | --- |
| 0 | 2367 | 92.18 | 77.4 | 2958 (2902) | 346.9 W |
| +100 | 2463 | 94.10 | 80.1 | 2998 (2955) | 356.5 W |
| +200 | 2504 | 95.10 | 80.3 | 3043 (3022) | 368.2 W |
| +300 | 2559 | 95.86 | 82.1 | 3049 (3037) | 372.4 W |
| +400 | 2650 | 96.99 | 83.4 | 3049 (3037) | 374.0 W |
| +500 | 2747 | **98.04** | **84.4** | 3047 (3037) | 375.2 W |

FPS rose at every step: **+6.4 % FPS and +9 % 1 % lows** from 0 to +500 for
+28 W. This matches the Reddit 5080 result (+6.3 % in Forza Horizon 6). Raising
XBAR also lifted the **~340 W ceiling** from the clock-cap sweep. The core
moved from about 2958 to 3047 MHz and power reached 375 W, so that limit was
tied to the crossbar or MSVDD side. The core now sits about three 15 MHz steps
below the 3090 cap, the usual temperature-based drop at about 72 °C.

**XBAR continued, 18:20–18:23:**

| XBAR | Live XBAR (MHz) | FPS | 1 % low | Core clock | Power | Result |
| --- | --- | --- | --- | --- | --- | --- |
| +600 | 2690 | 98.11 | 84.6 | 3051 | 370.1 W | ok, but **no gain over +500**. The live XBAR clock was lower |
| +700 | — | — | — | — | — | **System crash** (below) |

**Incident: hard crash at XBAR +700, 2026-11-04 18:23.** Within one second of
applying +700 (with core +450, cap 3090, memory +3000, power 111 %), the driver
logged nine `nvlddmkm` errors (event 14 and event 153 resets) in 17 s. Windows
then bugchecked with **`0x133` DPC_WATCHDOG_VIOLATION** (arg1 `0x1`: the
driver held the CPU in DPC routines too long) and rebooted at 18:26 (Kernel-Power
41). The minidump is `C:\Windows\Minidump\110426-19140-01.dmp`. The sweep
script's safe-restore couldn't run because the OS was hung in the driver.
After the reboot, every CLI setting was gone (stock). No BIOS override exists,
so nothing persisted. The MSVDD REL −50 mV was present again with no mVolt+
writes, which **confirms it's the NVIDIA driver default**.

**XBAR conclusion:** gains stop at about **+500** (live XBAR about 2750 MHz);
+600 adds nothing and +700 takes the whole system down. A failed XBAR step
can be a **bugcheck, not just a driver reset**, so XBAR needs a wider safety
margin than the core offset.

**BIOS override, round 1 (~18:38).** In the mVolt+ GUI (Direct method) the user
changed two values, saved, restarted the GPU and got "The new limits are active
and verified": **Memory new maximum 3000 → 4999** and **NVVDD current limit
300 → 330 A**. Everything else stayed at factory (table above). `--status`
confirmed `memory_offset_mhz_limit_max` 4999 and `power_channel_a."NVVDD OCP"`
330. The GPU restart wiped the CLI tune, and the sweep reapplied it.

**Override sweep, 18:41–18:52: core +450, cap 3090, XBAR +400, power 111 %, NVVDD 330 A, 140 s per step:**

| Memory | Live XBAR | FPS | 1 % low | Core clock avg (min) | Power | `0x4` samples |
| --- | --- | --- | --- | --- | --- | --- |
| +3000 | 2652 | 96.49 | 82.9 | 3048 (3037) | 374.0 W | 79/79 |
| +3500 | 2573 | 97.32 | 84.4 | 3049 (3037) | 374.4 W | 79/79 |
| +4000 | 2545 | 97.66 | 84.6 | 3047 (3037) | 377.0 W | 79/79 |
| +4500 | 2662 | **97.78** | **84.8** | 3047 (3037) | 378.4 W | 79/79 |

- **330 A changed nothing.** The +3000 row matches the 300 A run (96.99 FPS,
  3049 MHz, 374 W) within noise, and `0x4` is still active on every sample.
  **NVVDD current is not the limiter**, so the current-limit theory above is
  wrong for NVVDD. The core sits at 3047–3052 MHz, which is the +450 curve
  point at **945 mV** (2602 + 450). That is exactly MSVDD REL after the
  Black-screen fix (995 − 50 = 945 mV). That suggested an MSVDD voltage
  ceiling, but the offset test below rules it out.
- **Memory above +3000 still scales**, with no regression up to +4500:
  +1.3 % FPS and +2.2 % 1 % lows over +3000 for about +4 W. Each step is near
  the ±1 FPS noise, but the trend is monotonic over four steps.

**Offset check, 18:52–18:58: cap 3090, XBAR +400, memory +3000, 111 %, NVVDD 330 A:**

| Core | FPS | 1 % low | Core clock avg (min) | Power | Inferred voltage |
| --- | --- | --- | --- | --- | --- |
| +450 (from above) | 96.49 | 82.9 | 3048 (3037) | 374.0 W | ~945 mV |
| +475 | 96.85 | 82.8 | 3052 (3037) | 372.4 W | ~940 mV |
| +500 | 97.49 | 83.2 | 3047 (3037) | 366.9 W | ~935 mV |

**The clock stays at ~3047 MHz while voltage and power drop**, so the limit
is a clock ceiling, not voltage, current or power. It is the 3090 cap minus
three 15 MHz temperature bins at ~72 °C (3090 − 45 = 3045). 3090 is mVolt+'s
`clock_range_mhz.limit_max`, and the override's Clocks tab has no setting for
it. **The core is at its ceiling.** What's left: lower voltage at the same
clock (+500 saved 7 W), a cooler GPU (each bin lost is +15 MHz), memory
above +3000, and XBAR +500. The `0x4` flag is set even in this clock-limited
state, so on this driver it doesn't prove a power limit.

**Overrides removed (~19:15).** The user removed every BIOS override in the
GUI. `--status` shows the memory maximum back at 3000 and NVVDD OCP at 300 A,
and the card was back at stock.

**XBAR 0 vs +450 within stock limits, 19:19–19:30.** Memory +3000, new fan
curve active, 140 s per step:

| Tune | XBAR | Live XBAR | FPS | 1 % low | Core clock | Power | Temp |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Performance: +450, cap 3090, 111 % | 0 | 2380 | 92.09 | 78.4 | 2963 | 340.6 W | 65.9 °C |
| Performance: +450, cap 3090, 111 % | **+450** | 2668 | **96.87** | **82.4** | 3049 | 371.8 W | 69.3 °C |
| Undervolt: +468, cap 2880, 100 % | 0 | 2358 | 89.83 | 76.1 | 2852 | 314.1 W | 65.5 °C |
| Undervolt: +468, cap 2880, 100 % | **+450** | 2590 | **92.11** | **78.0** | 2857 | **304.7 W** | 64.3 °C |

- Performance tune: XBAR +450 gives **+5.2 % FPS and +5.1 % 1 % lows** for
  +31 W. Part of that comes from the core reaching the cap (2963 → 3049 MHz).
- Undervolt tune: XBAR +450 gives **+2.5 % FPS and +2.4 % lows at no power
  cost** (305 W vs 314 W, within run-to-run spread). The core is capped at
  ~890 mV either way.
- **Undervolt + XBAR +450 matches performance + XBAR 0** (92.11 vs 92.09 FPS)
  **using 36 W less.** That makes it the daily candidate.
- The fan curve kept the performance runs at 66–69 °C instead of 72 °C. The
  `+450` clock still sat at 3049 MHz, so at 69 °C the temperature steps aren't
  all recovered.

**Afterburner curve + mVolt+ XBAR, ~19:35–19:42.** The user applied the
Afterburner undervolt: curve flat at ~2880 MHz from 895 mV (screenshot: knee at
895 mV, points up to ~2865 at 885 mV), power 111 %, memory +3000. mVolt+
`--status` doesn't see Afterburner's curve or memory offset (core 0, memory 0,
clock range unlocked), but nvidia-smi shows memory at 18001 MHz (stock 15001),
so +3000 is active. Then **only** `mVolt+.exe --xbar-offset 450` was written.
"Unspecified direct controls are left unchanged", so the Afterburner settings
stayed. Measured with a measure-only script (PresentMon + nvidia-smi, 140 s):

| Afterburner curve | XBAR | Live XBAR | FPS | 1 % low | Clock | Power | Temp / fan |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 2880 @ 895 mV, 111 %, +3000 | 0 | 2371 | 89.67 | 75.1 | 2857 | 311.7 W | 65.4 °C / 79 % |
| 2880 @ 895 mV, 111 %, +3000 | **+450** | 2554 | **91.67** | **76.7** | 2861 | **303.1 W** | 64.9 °C / 80 % |

- **+2.2 % FPS, +2.1 % 1 % lows, −8.6 W.** That reproduces the mVolt+ undervolt
  result (+2.5 %, −9 W) with a different tool applying the curve, so the
  XBAR gain at the undervolt is real. The power drop showed up twice. Its
  cause is unknown.
- **The Afterburner curve and the mVolt+ `+468 / cap 2880` undervolt perform the
  same** (89.67 vs 89.83 FPS at XBAR 0), as expected for the same V/F point.
- On the Afterburner curve the throttle flag is `0x1` (GPU idle), not `0x4`, on
  every sample. nvidia-smi reports flags differently depending on how the clock
  is limited, which again shows the flag can't be read as a power limit.
- No driver errors.

**Afterburner-only curve sweep, 19:47–20:01.** The user chose Afterburner
alone for daily use. XBAR was reset to 0 (`--xbar-offset 0`, verified) and
mVolt+ closed. A first sweep started at 19:46 with XBAR +450 still applied
from the earlier test. It was stopped before any step was measured, so it
produced no results. Curves were written by
`Set-AfterburnerVfCurve.ps1` into profile slot 2 and loaded with
`MSIAfterburner.exe -Profile2`. Each was +480 MHz from 810 mV up to the
ceiling and flat above it. Memory +3000, 111 %, 140 s per step:

| Ceiling | Target clock | FPS | 1 % low | Clock avg | Power | Temp |
| --- | --- | --- | --- | --- | --- | --- |
| 895 mV, +468 (original curve) | 2887 | 89.67 | 75.1 | 2857 | 311.7 W | 65.4 °C |
| **900 mV** | 2925 | **90.70** | **76.1** | 2890 | 316.9 W | 65.7 °C |
| 915 mV | 2970 | 90.53 | 75.8 | 2919 | 323.1 W | 66.2 °C |
| 925 mV | 3015 | 90.50 | 76.3 | 2929 | 323.9 W | 65.9 °C |
| 935 mV | 3045 | 91.05 | 73.4 | 2933 | 325.1 W | 66.1 °C |
| 945 mV | 3082 | 91.07 | 73.1 | 2937 | 326.2 W | 65.9 °C |

- **Without XBAR the core stalls at about 2930 MHz** whatever the ceiling,
  with `0x4` set and power far under 400 W. It's the same wall as the mVolt+
  XBAR 0 runs (2958–2963 MHz), which XBAR lifted to 3049. Above 900 mV the
  card spends 9 W more for nothing measurable, and the 1 % lows get worse
  at 935–945.
- **900 mV / +480 is the daily curve:** +1.1 % FPS and +1.3 % lows over the
  original for 5 W. Saved as **Profile2** and applied.
- **945 mV / +480 is saved as Profile3** for gaming sessions *with* XBAR
  (`Set-GpuXbar.ps1`). Without XBAR it gains nothing. The combination has
  not been measured yet.
- Profile1/Profile5 (the user's hotkeys) and `[Startup]` are unchanged.
  `Set-AfterburnerVfCurve.ps1` backs up the .cfg before every write
  (`*.cfg.bak-*` next to it). Copy after this step:
  [`data/titan-rtx-5080/afterburner-profile.cfg`](data/titan-rtx-5080/afterburner-profile.cfg).

**Afterburner profiles reorganized (~20:05, user request).** Afterburner was
closed, the .cfg backed up (`*.bak-<stamp>-before-reorg`), the old
Profile1 and Profile5 (old 2887 @ 895 mV curve) deleted, and Profile2 moved to
**Profile1 = 900 mV / +480, flat 2925 MHz**. **Profile3 = 945 mV / +480, flat
3082 MHz** stays as is. `[Startup]` is unchanged. Afterburner was restarted
with `-Profile1`, and decoding confirmed both curves.

**Profile1 + XBAR +500 (`Set-GpuXbar.ps1 -Offset 500`), 20:06:**

| Setup | FPS | 1 % low | Clock | Power | Temp |
| --- | --- | --- | --- | --- | --- |
| Profile1 (900 mV), XBAR 0 | 90.70 | 76.1 | 2890 | 316.9 W | 65.7 °C |
| Profile1 (900 mV), **XBAR +500** | **92.09** | 75.4 | 2896 | **307.1 W** | 65.3 °C |

+1.5 % FPS for 10 W *less*, with no driver errors. The 1 % low is within noise.
XBAR was then reset to 0.

**Lower ceilings, 20:24–20:38 (XBAR 0, +480, slot 2).** An earlier run at
20:10 was invalid: the sweep piped the script into `Select-Object -First 1`,
which stopped it before `-Apply`, so every step measured Profile1 (2890 MHz
throughout). The rerun logged the live clock after each switch:

| Ceiling | Target | FPS | 1 % low | Clock | Power | FPS/W |
| --- | --- | --- | --- | --- | --- | --- |
| stock | — | 84.20 | 71.3 | 2763 | 358.8 W | 0.235 |
| 900 mV (Profile1) | 2925 | 90.70 | 76.1 | 2890 | 316.9 W | 0.286 |
| 895 mV | 2895 | 90.26 | 75.4 | 2871 | 313.0 W | 0.288 |
| 885 mV | 2842 | 89.29 | 71.4 | 2835 | 306.6 W | 0.291 |
| **875 mV (Profile2)** | 2820 | **89.21** | **74.7** | 2806 | **301.3 W** | 0.296 |
| 865 mV | 2767 | 88.35 | 73.9 | 2762 | 294.0 W | 0.300 |
| 850 mV | 2715 | 87.19 | 73.2 | 2712 | 285.1 W | 0.306 |

Each step down costs about 1 FPS per 6–8 W, which is linear with no cliff.
Below 900 mV the `0x4` flag disappears (only `0x1`), so the curve, not the
~2930 MHz wall, is the limit. **875 mV is saved as Profile2:** −1.6 % FPS vs
Profile1 for −16 W, and still +6 % over stock at −58 W. Profile1 (900 mV)
and Profile3 (945 mV) are unchanged. 850 mV is the most efficient tested
(+3.6 % over stock at −74 W) if lower power matters more.

**GPU fan curve (FanControl), 19:04.** FanControl V285 runs the case fans
from `C:\Program Files (x86)\FanControl\Configurations\titan.json`. The GPU
fans had no curve (`SelectedFanCurve: null`), so the card's own curve ran them:
54 % (about 1740 rpm) at 72 °C in the sweeps. Added a **`GPU Card`** graph
curve on `NVApiWrapper/0-GB203-A/sensor/0` and assigned GPU Fan 1–3 to it.
It is off at idle (44–45 °C, fans stopped) and ramps hard where the clock
loses its temperature bins:

| GPU °C | ≤54 | 55 | 60 | 64 | 68 | ≥71 |
| --- | --- | --- | --- | --- | --- | --- |
| Fan % | 0 | 30 (min spin, ~1200 rpm) | 50 | 70 | 90 | 100 |

Hysteresis is 1 °C up and 4 °C down, with a 3 s down response, so the fans
stop only below about 51 °C instead of cycling at 55. Copy:
[`data/titan-rtx-5080/fancontrol-titan.json`](data/titan-rtx-5080/fancontrol-titan.json).
To restore after a reinstall, copy it to FanControl's `Configurations` folder
with FanControl closed. The previous version is in the session scratchpad as
`titan.backup-20261104.json`. Undo: in FanControl set GPU Fan 1–3 to no curve.

**Conclusion:** the core offset limit is about +525. Use **+500** day to day for
margin, because the offset also raises XBAR through the 0.9 ratio. The 3DMark
monitoring chart showed each Steel Nomad loop is about **70 s**, so later
sweeps measure 140 s (2 full loops).

## Recheck on Windows

The scripts are in [`powershell/rtx-5080/`](../powershell/rtx-5080/README.md):
`Get-GpuTuneState.ps1` (snapshot), `Set-GpuUndervolt.ps1` (apply/reset,
needs admin), `Measure-GpuLoad.ps1` (load logger) and
`Get-AfterburnerVfCurve.ps1` (curve decoder). The raw commands are below.

Read-only. `--status` and `--list-gpus` don't need elevation.

```powershell
# Current applied tuning (JSON); pipe to Out-Host so PowerShell waits
& 'C:\Software\mVolt+.exe' --status | Out-Host
(& 'C:\Software\mVolt+.exe' --status | ConvertFrom-Json) |
  Select-Object active_profile, power_limit_percent, core_offset_mhz, memory_offset_mhz, msvdd_offsets_uv, nvvdd_offsets_uv

# Driver and VBIOS
nvidia-smi --query-gpu=driver_version,vbios_version,power.default_limit,power.max_limit --format=csv

# Is Afterburner running / set to start at logon?
Get-Process MSIAfterburner, RTSS -ErrorAction SilentlyContinue
Get-ScheduledTask -TaskName MSIAfterburner | Select-Object TaskName, State
```

The status JSON reports voltages in **microvolts** (`-50000` = −50 mV), but
the CLI takes **millivolts**.
