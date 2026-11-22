# ADB over Wi-Fi

Android 11+ wireless debugging uses a random port and needs a one-time pairing
per PC.

```powershell
adb mdns services                      # finds _adb-tls-connect at 10.10.1.25:<port>
# Phone: Developer options → Wireless debugging → Pair device with pairing code
adb pair 10.10.1.25:<pair-port> <code> # only once per PC
adb connect 10.10.1.25:<connect-port>  # port changes each time wireless debugging is toggled
```

TITAN is paired (re-paired 2026-11-07). If `adb connect` prints only `failed to
connect` while the port is open, check `%TEMP%\adb.log` (set `ADB_TRACE=adb`).
`SSLV3_ALERT_CERTIFICATE_UNKNOWN` means the phone has dropped the pairing, so pair
again. Android turns wireless debugging off at every
reboot, and the connect port changes each time it comes back (42857 → 35675
across the 2026-10-29 reboot). The pairing survives, so only `adb mdns
services` + `adb connect` are needed again.

When a loop feeds package names to `adb shell`, use `adb shell -n`. Without it,
`adb shell` reads stdin and swallows the rest of the list.

