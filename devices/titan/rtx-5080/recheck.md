# Recheck on Windows

The scripts are in [`powershell/rtx-5080/`](../../../powershell/rtx-5080/README.md):
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
