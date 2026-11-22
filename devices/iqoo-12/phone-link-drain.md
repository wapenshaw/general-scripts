# Issue: fast idle drain from Phone Link wakeups — 2026-11-07

**Symptom:** about 2.3%/h drain with the screen off (1,237 mAh over 22 h,
learned capacity about 2,406 mAh). The CPU was awake 12 h of the 22 h screen-off.

**Cause:** Phone Link's local-network keepalive. On TITAN, `CrossDeviceService`
and `PhoneExperienceHost` each send UDP to the phone about every 2.5 s, so
there are two streams. Both go to sockets that Link to Windows
(`com.microsoft.appmanager`, uid 10339) holds open on the phone: the destination
ports appear in `/proc/net/udp` bound `0.0.0.0` by uid 10339. Each packet wakes
the phone from suspend. `dumpsys connmetrics` → `WakeupStats(wlan0)` showed
57,499 wakeups in 46 h. batterystats showed `wifi wakeup` 34,781 times and
`qcom_rx_wakelock` for 4 h.

`WakeupEvent` lists most of them as `uid: -1` / `no uid`. That does **not** mean
no listener: netd can't tag packets for unconnected UDP sockets bound to
`0.0.0.0`. To find the real owner, convert the destination port to hex and look
it up in `/proc/net/udp`.

**How it was traced:** `WakeupEvent` lines give `srcIp`/`srcPort`/`dstPort`.
Matching the source port with `Get-NetUDPEndpoint` on TITAN gives the PC
process. Leave out the adb session's own port (uid 2000).

**Not a fix:** restarting both processes and reopening Phone Link (`ms-phone:`)
gave 0 wakeups for 3 min. About 50 min later both streams were back at roughly
50/min on new ports (2026-11-07 20:25–20:49). The quiet window was only the time
before the session came back. The .25 reservation doesn't affect this either.

**Fix (2026-11-07):** Phone Link is in daily use, so it stays. Wakeups from
TITAN in 3 min with the screen off:

| State | Total | CrossDeviceService | PhoneExperienceHost |
| --- | --- | --- | --- |
| Baseline | ~110 | — | — |
| All Cross Device features off (Settings → Bluetooth & devices → Mobile devices → phone) | 57 | 41 | 16 |
| Plus the firewall rule below, with Phone Link connected | **13** | **0** | 13 |

The feature switches don't stop the `CrossDeviceService` keepalive. Only the top
"Allow this PC to access content…" switch does, and that also disables Phone
Link. Re-pairing didn't help either (the user checked). So TITAN has an
outbound Windows Firewall rule:

```powershell
# elevated
New-NetFirewallRule -DisplayName 'Block CrossDeviceService to LAN (phone battery)' `
  -Direction Outbound -Action Block -RemoteAddress LocalSubnet -Profile Any `
  -Program (Get-Process CrossDeviceService).Path
# undo
Remove-NetFirewallRule -DisplayName 'Block CrossDeviceService to LAN (phone battery)'
```

With the rule in place, Phone Link messages and notifications still work
(refresh the connection once in the Phone Link UI). The rule matches the
versioned path `…\WindowsApps\MicrosoftWindows.CrossDevice_<version>_x64__cw5n1h2txyewy\`,
so a Store update stops it matching. Re-create it if the wakeups come back.
The remaining Phone Link stream (about 4 wakeups/min) stops when Phone Link
is quit at night.

## Baseline for the next check — 2026-11-07 20:49 IST

Unplugged at 99%, and batterystats reset on unplug (`dumpsys batterystats
--reset` is refused for the shell on Android 16). Phone Link was still running
both streams, about 37 wakeups/min (`WakeupStats(wlan0)`: 2,601 total, 2,272
`no uid`, in 3,667 s). Already applied at that point: clone user removed, 18
apps uninstalled, Amazon restricted in the background, Bluetooth and Wi-Fi
scanning off, Jio on 4G (registry shows `JIO 4G`, LTE), Wi-Fi calling active on
both SIMs. At the next check, compare screen-off mAh/h, CPU-awake share with the
screen off, and the wakeup rate.

Smaller drains found at the same time:
- GMS in the App clone user (u999) holding `*location*` for 1 h 17 m. The clone
  user had no third-party apps, only Facebook's updater and system packages.
  Removed with `pm uninstall -k --user 999` for `com.facebook.appmanager`,
  `com.google.android.gms`, `com.google.android.gsf`,
  `com.google.android.webview` and `com.google.android.ext.services`. Restore
  with `cmd package install-existing --user 999 <pkg>`. User 999 can't be
  stopped (`am stop-user` fails with -4) because it is tied to user 0. After that,
  App clone was reset in Settings, which deleted user 999 entirely; only user 0
  remains. Morphe's microG (`app.revanced.android.gms`, u0a351) is separate and
  was not touched.
- Amazon Shopping's `BackupUploaderService` job, 50 min
- Google Fit and Digital Wellbeing `SigCollector`, about 800 wakeups each

## Battery cleanup — 2026-11-07

Fully uninstalled with `pm uninstall` (reinstall from Play if needed):

- Background drains: Google Fit (never opened; 515 activity/location checks a
  day), AccuBattery (foreground service 24/7), bitchat (Bluetooth mesh service)
- Not opened in the usage history: Prime Video, Amazon Music, F1 TV, The Room
  Two, Epic Games, Grayjay, Facebook, Windscribe, Virgin Pulse, Philips
  Kitchen+, Zunpulse, Urban Company, BookMyShow, Loftlog, labhouse audio app

Changed:

- Amazon Shopping: `cmd appops set in.amazon.mShop.android.shopping
  RUN_ANY_IN_BACKGROUND ignore` (undo with `allow`)
- Location scanning off: `ble_scan_always_enabled=0` and
  `wifi_scan_always_enabled=0`. Google Play services had held Bluetooth scanning
  for 8 h 48 m in one day.

Kept on purpose: Fossil (watch), Okta (work 2FA), Airtel Thanks (call
screening), Phone Link.

