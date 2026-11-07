# RTX 5080 tuning scripts

Scripts for TITAN's RTX 5080 (Gigabyte, VBIOS `98.03.3b.40.11`) and
[mVolt+](https://github.com/b00nz/mVolt). The card's details, tuning history
and before/after measurements are in
[`devices/titan-rtx-5080.md`](../../devices/titan-rtx-5080.md).

| Script | Does | Elevation |
| --- | --- | --- |
| [`Get-GpuTuneState.ps1`](Get-GpuTuneState.ps1) | Snapshot: mVolt+ status (offsets in mV, clock lock), driver/VBIOS, live clocks, Afterburner process and logon task | No |
| [`Set-GpuUndervolt.ps1`](Set-GpuUndervolt.ps1) | Applies the full tune in one verified write: core +450, cap 3090, memory +3000, power 111 %, XBAR +400. `-XbarOffset 500` for the faster setting, `-Preset Afterburner` for the old +468/2880 undervolt, `-Reset` for stock. Supports `-WhatIf` | **Yes** |
| [`Set-GpuXbar.ps1`](Set-GpuXbar.ps1) | Sets **only** the XBAR offset (default +450) on top of an Afterburner curve, for gaming sessions; `-Reset` returns it to 0. Leaves Afterburner's curve, memory and power alone | **Yes** |
| [`Set-AfterburnerVfCurve.ps1`](Set-AfterburnerVfCurve.ps1) | Writes an undervolt curve (offset up to a voltage ceiling, flat above) into an Afterburner profile slot and optionally loads it with `-Apply` | **Yes** |
| [`Measure-GpuLoad.ps1`](Measure-GpuLoad.ps1) | Logs `nvidia-smi` once per second during a load run to CSV and prints avg/min/max and throttle reasons | No |
| [`Invoke-GpuTuneSweep.ps1`](Invoke-GpuTuneSweep.ps1) | Steps through tuning configs (offset, target voltage, memory, power) under a running load. Measures FPS and 1 % lows (PresentMon) plus clock, power and temperature for each. Reverts to safe settings and stops on a crash or driver reset | **Yes** |
| [`Get-AfterburnerVfCurve.ps1`](Get-AfterburnerVfCurve.ps1) | Decodes an MSI Afterburner `.cfg` V/F curve: per-point voltage, offset, and the voltage where the curve flattens | No |

## After a fresh Windows install

1. Install the NVIDIA driver. Note its version, because mVolt+ behaviour has
   changed between drivers (see the record).
2. Download `mVolt+.exe` from the
   [releases](https://github.com/b00nz/mVolt/releases) to `C:\Software\`. The
   scripts default to that path; pass `-MVoltPath` to use another.
3. For FPS measurement, download the PresentMon CLI
   (`PresentMon-<ver>-x64.exe`, Intel-signed) into `C:\Software\PresentMon\`:

   ```powershell
   gh release download -R GameTechDev/PresentMon -p 'PresentMon-*-x64.exe' -D C:\Software\PresentMon
   ```

4. If MSI Afterburner is installed, keep its profile at defaults or quit it.
   It re-applies its own curve at logon and after resume.
4. Check the adapter ID still matches. It should, unless the card moves to
   another PCIe slot:

   ```powershell
   & 'C:\Software\mVolt+.exe' --list-gpus | Out-Host
   ```

   If it changed, pass `-AdapterId` to `Set-GpuUndervolt.ps1` or update its
   default.
5. Apply and check, from an elevated shell:

   ```powershell
   .\Set-GpuUndervolt.ps1
   .\Get-GpuTuneState.ps1
   ```

6. Measure against a fixed load (for example a looped 3DMark Steel Nomad),
   one run per configuration:

   ```powershell
   .\Measure-GpuLoad.ps1 -Label stock  -OutputDirectory $env:TEMP\gpu-runs
   .\Measure-GpuLoad.ps1 -Label uv2880 -OutputDirectory $env:TEMP\gpu-runs
   ```

CLI writes last until reboot or a driver reset. To persist them, save the
settings as a profile in the mVolt+ GUI, set it as the startup profile, and
enable Start with Windows.

## How the undervolt works

The stock V/F curve maps each voltage to a clock. `--core +468` lifts the whole
curve, so every voltage now reaches a higher clock. `--clock-range 0,2880` caps
the clock at 2880 MHz, so the GPU stops at the **lowest** voltage that reaches
2880 MHz (about 895 mV on this card). That is the same result as dragging one
Afterburner curve point up and flattening everything to its right.
