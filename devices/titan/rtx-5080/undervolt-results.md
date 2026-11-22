# Before/after: stock vs undervolt — 2026-11-04

**Load:** custom 3DMark Steel Nomad loop, running the whole time. The undervolt
was applied live between the two runs.
**Method:** [`Measure-GpuLoad.ps1`](../../../powershell/rtx-5080/Measure-GpuLoad.ps1),
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

