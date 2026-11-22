# Change log

| When | Change | Undo |
| --- | --- | --- |
| 2026-11-08 08:2x | Disabled VBS (`DeviceGuard\EnableVirtualizationBasedSecurity=0`), Memory Integrity (`Scenarios\HypervisorEnforcedCodeIntegrity\Enabled=0`) and hypervisor launch (`bcdedit /set {current} hypervisorlaunchtype off`) so ThrottleStop can write voltage offsets. Docker Desktop (WSL2) will not start while this is in effect. | See below |
| 2026-11-08 ~08:30 | BIOS: Load Optimized Defaults, XMP Profile 1, CPU Cooler Tuning = Intel Default Settings (see [BIOS section](bios-settings.md)) | Restore `devices/private/bios-screenshots-config/*.ocb` |
| 2026-11-08 ~08:45 | After reboot VBS was still running (status 2, no services) with the hypervisor present. Also disabled Windows Hello Enhanced Sign-in Security (`Scenarios\WindowsHello\Enabled=0`; no biometric device is attached) and VSM launch (`bcdedit /set {current} vsmlaunchtype off`). | See below |
| 2026-11-08 09:04 | ThrottleStop FIVR: CPU Core and CPU P Cache offset −25.4 mV (Adaptive), "Do not save voltages" (resets on reboot). | FIVR → Zero Offset, or reboot |
| 2026-11-08 09:06 | ThrottleStop FIVR: Core + P Cache −50.8 mV ([Run 2](runs.md)). | Zero Offset or reboot |
| 2026-11-08 09:19 | ThrottleStop FIVR: Core + P Cache −100.6 mV ([Run 3](runs.md), [Run 4](runs.md) CoreCycler). Still active. | Zero Offset or reboot |
| 2026-11-08 09:30 | CoreCycler `config.ini`: `maxIterations` 10000→1, `enableUpdateCheck` 1→0, `useWindowsEventLog` 1→0. Original saved as `config.ini.orig`. | Copy `config.ini.orig` back |
| 2026-11-08 11:18 | BIOS visit 1 (`devices/private/OC-Just-Minus-100.ocb`, `round1.jpg`): VR Voltage Limit 1.400 V, CPU Core Voltage Mode Adaptive + Offset, offset − 0.100 V, Speed Shift Enabled, Long Duration Maintained 128 s, CPU Current Limit 307 A, CPU Under Voltage Protection Disabled, IA CEP Enabled. **Enhanced Turbo Auto→Enabled (not planned; asked user to revert to Auto for the [Run 5](runs.md) baseline).** No ring offset option on this BIOS. | Load `STock.ocb` or set fields back to Auto |
| 2026-11-08 10:07 | **HWiNFO CSV logging stopped** (file ends with footer); sensor data for CoreCycler cores 7–15 lost; CoreCycler result unaffected. New log per BIOS state from now: `titan-sensors-bios1.csv`. | — |
| 2026-11-08 11:51 | BIOS: VR Voltage Limit and CPU VR Voltage Limit 1.400 → Auto (isolating the [Run 5](runs.md) EDP/Other limiter). ThrottleStop FIVR read back Core −0.0996 / P Cache −0.0996 from the BIOS offset (covers the ring) and IA IccMax 511.75 A (BIOS "CPU Current Limit 307" is not that register). | Set 1.400 again |

Revert VBS, HVCI, Enhanced Sign-in Security and the hypervisor (then reboot):

```powershell
sudo pwsh -NoProfile -Command "Set-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity' Enabled 1; Set-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\WindowsHello' Enabled 1; Set-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard' EnableVirtualizationBasedSecurity 1; bcdedit /set '{current}' hypervisorlaunchtype auto; bcdedit /deletevalue '{current}' vsmlaunchtype"
```

