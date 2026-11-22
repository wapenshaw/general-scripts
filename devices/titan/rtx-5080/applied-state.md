# State at inspection — 2026-11-04 ~16:50

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

### Afterburner profile (applied at every logon until it was reset at 16:57; see the [change log](change-log.md))

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

