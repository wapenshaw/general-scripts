# TITAN: RTX 5080 tuning (mVolt+ and MSI Afterburner)

Last inspected: **2026-11-04**. Times below use **Asia/Kolkata (IST, UTC+05:30)**.
Host details are in [titan.md](../README.md).
## Contents
- [Applied state and factory BIOS limits](applied-state.md)
- [Undervolt results and tool interaction](undervolt-results.md)
- [Community tips and XBAR findings](community-tips.md)
- [Change log](change-log.md)
- [Recheck on Windows](recheck.md)
- [Afterburner profile](data/afterburner-profile.cfg)
- [FanControl configuration](data/fancontrol-titan.json)

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

## Current best tune (2026-11-04)

Applied with
[`Set-GpuUndervolt.ps1`](../../../powershell/rtx-5080/Set-GpuUndervolt.ps1)
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

