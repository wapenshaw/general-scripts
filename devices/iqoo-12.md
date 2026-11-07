# iQOO 12 (phone)

Last inspected: **2026-10-29**. Times below use **Asia/Kolkata (IST, UTC+05:30)**.

## Device

| Item | Value |
| --- | --- |
| Model | iQOO 12 (**I2220**, project PD2307F, global/India `_EX_` build) |
| Operating system at inspection | OriginOS 6 on Android 16 (SDK 36), build **PD2307F_EX_A_16.2.18.1.W30** |
| Security patch | 2026-09-01 |
| LAN address | **10.10.1.152** (Wi-Fi) |
| Users | 0 (owner), 999 (App clone) |

## Default apps

| Role | App |
| --- | --- |
| Home | Nova Launcher (`com.teslacoilsw.launcher`) |
| SMS | Jio Messages (`com.jio.messageslite`) |
| Dialer | Google Phone (`com.google.android.dialer`) |
| Browser | Microsoft Edge (`com.microsoft.emmx`) |
| Keyboard | SwiftKey; Gboard kept as fallback |
| Assistant | Google (`com.google.android.googlequicksearchbox`) |
| Call screening | Airtel Thanks (`com.myairtelapp`) |

## ADB over Wi-Fi

Android 11+ wireless debugging uses a random port and needs a one-time pairing
per PC.

```powershell
adb mdns services                       # finds _adb-tls-connect at 10.10.1.152:<port>
# Phone: Developer options → Wireless debugging → Pair device with pairing code
adb pair 10.10.1.152:<pair-port> <code> # only once per PC
adb connect 10.10.1.152:<connect-port>  # port changes each time wireless debugging is toggled
```

TITAN is paired (2026-10-29). Android turns wireless debugging off at every
reboot, and the connect port changes each time it comes back (42857 → 35675
across the 2026-10-29 reboot). The pairing survives, so only `adb mdns
services` + `adb connect` are needed again.

When a loop feeds package names to `adb shell`, use `adb shell -n`. Without it,
`adb shell` reads stdin and swallows the rest of the list.

## Debloat — 2026-10-29

Removed with `pm uninstall -k --user 0`, so the APKs stay on `/system` and
every removal is reversible. Package lists from before and after, plus the
command log, are in `private/iqoo-12/`.

### Already removed before this session (30)

`com.android.VideoPlayer`, `com.android.bbklog`, `com.android.bookmarkprovider`,
`com.android.browser`, `com.bbk.account.overlay`, `com.bbk.cloud.overlay`,
`com.bbk.iqoo.logsystem`, `com.facebook.services`, `com.facebook.system`,
`com.google.android.adservices.api`, `com.google.android.apps.nbu.files`,
`com.google.android.feedback`, `com.google.android.onetimeinitializer`,
`com.google.android.partnersetup`, `com.vivo.Tips`, `com.vivo.browser`,
`com.vivo.browser.overlay`, `com.vivo.desktopstickers`, `com.vivo.feedback`,
`com.vivo.fuelsummary`, `com.vivo.gamecube`, `com.vivo.magazine`,
`com.vivo.musicwidgetmix`, `com.vivo.notes`, `com.vivo.numbermark`,
`com.vivo.setupwizard`, `com.vivo.share`, `com.vivo.share.overlay`,
`com.yozo.vivo.office`, `com.yozo.vivo.office.overlay`.

`com.facebook.appmanager` is also gone for user 0. It is still installed in
the App clone user (999).

### Uninstalled for user 0 (28)

| Group | Packages |
| --- | --- |
| vivo promo / ecosystem | `com.vivo.hybrid` (Quick Apps), `com.vivo.game` (Game Center), `com.vivo.unionpay`, `com.vivo.vhome`, `com.vivo.tws.vivotws`, `com.vivo.easyshare` |
| vivo launcher widgets | `com.vivo.countdownwidget`, `com.vivo.timerwidget`, `com.vivo.doubletimezoneclock`, `com.vivo.musicmixcard`, `com.vivo.widget.cleanspeed`, `com.vivo.healthwidget` |
| vivo utilities | `com.vivo.weather`, `com.vivo.widgetweather`, `com.vivo.compass`, `com.vivo.calculator`, `com.vivo.stepcount`, `com.vivo.smartanswer` |
| Google | `com.android.chrome`, `com.google.android.apps.messaging`, `com.google.android.apps.bard` (Gemini), `com.google.android.projection.gearhead` (Android Auto), `com.google.android.apps.tachyon` (Meet), `com.google.android.apps.restore`, `com.google.android.apps.setupwizard.searchselector`, `com.google.android.printservice.recommendation` |
| AOSP extras | `com.android.email.partnerprovider`, `com.android.egg` |

### Protected by vivo — restricted instead (13)

OriginOS refuses to uninstall these (`DELETE_FAILED_USER_RESTRICTED`). It also
blocks `pm disable-user`, `pm hide` and `pm suspend` from the shell
(`SecurityException: … no root permission`). App ops and permission revokes
still work, so each package got:

```sh
cmd appops set <pkg> RUN_IN_BACKGROUND ignore
cmd appops set <pkg> RUN_ANY_IN_BACKGROUND ignore
pm revoke <pkg> android.permission.POST_NOTIFICATIONS
am force-stop <pkg>
```

`com.vivo.appstore`, `com.iqoo.website`, `com.vivo.hiboard`,
`com.vivo.cardstore`, `com.vivo.pcsuite`, `com.android.bbkmusic`,
`com.vivo.ai.agent`, `com.vivo.assistant`, `com.vivo.globalsearch`,
`com.bbk.cloud`, `com.vivo.pushservice`, `com.vivo.weather.provider`,
`com.vivo.videoeditor`.

An OTA may reset these app ops. Re-check after system updates.

### Deliberately kept

- **Core vivo services** (removing them bootloops or breaks Settings):
  `com.vivo.daemonService`, `com.vivo.appfilter`, `com.vivo.abe`,
  `com.vivo.pem`, `com.vivo.sps`, `com.vivo.epm`, `com.vivo.vms`,
  `com.bbk.account`, `com.vivo.cota`, `com.bbk.updater`.
- **System UI and features:** `com.android.launcher3` (vivo recents/fallback
  home), `com.bbk.theme`, `com.vivo.nightpearl` (AOD), `com.vivo.upslide`,
  `com.vivo.gamewatch` (Ultra Game Mode), `com.vivo.ai.aie`,
  `com.vivo.ai.intellicore` and `com.vivo.aiengine` (camera/system AI),
  `com.vivo.livewallpaper.*` (`box` is the default wallpaper component).
- **Apps:** camera, `com.vivo.gallery` (the camera thumbnail opens it), file
  manager, sound recorder, Gmail, Calendar, Photos, Digital Wellbeing,
  Gboard.
- **Link to Windows** (`com.microsoft.appmanager`,
  `com.microsoft.deviceintegrationservice`,
  `com.microsoftsdk.crossdeviceservicebroker`): feeds TITAN's
  `C:\Users\tHeSiD\CrossDevice\` folder.

### Undo

```sh
adb shell cmd package install-existing <pkg>                # uninstalled packages
adb shell cmd appops set <pkg> RUN_ANY_IN_BACKGROUND allow  # restricted packages
adb shell cmd appops set <pkg> RUN_IN_BACKGROUND allow
adb shell pm grant <pkg> android.permission.POST_NOTIFICATIONS
```

After the changes there were no entries in the crash buffer. Settings and
Nova kept working.

## Issue: swipe-up home sometimes shows the vivo launcher — 2026-10-29

### Symptom

With Nova set as the default home app and gesture navigation on, swiping up
to go home sometimes showed the stock vivo launcher instead of Nova. The user
tied it to restarts.

### Findings

- **Nova was already the default everywhere the shell can see:** HOME role
  holder, resolved `MAIN/HOME` activity, and on the Doze whitelist.
- **`com.android.launcher3` is the vivo launcher.** It contains
  `com.bbk.launcher2.Launcher` and is also the system recents provider
  (`config_recentsComponentName` =
  `com.android.launcher3/com.android.quickstep.RecentsActivity`). Every gesture
  goes through its `com.android.quickstep.TouchInteractionService`, even when
  another launcher is the default.
- **The vivo launcher starts before unlock; Nova can't.** The vivo launcher is
  `DIRECT_BOOT_AWARE`; Nova is not. Boot timeline of the 2026-10-29 reboot:

  | Time | Event |
  | --- | --- |
  | 21:53:42 | `com.android.launcher3` process (with the gesture service) starts, before unlock |
  | 21:53:53 | Home is Settings' `FallbackHome` placeholder |
  | 21:54:41 | User unlocks |
  | 21:54:43 | Nova starts |

  The gesture service is set up before Nova exists and isn't restarted after
  unlock.
- **Didn't reproduce after that reboot.** That boot followed the change below.
  Every swipe-up, both before and after the reboot, logged
  `wm_set_resumed_activity` for Nova. No vivo launcher activity was resumed in
  about 15 minutes of event-log capture.
- **The vivo launcher depends on the vivo card store.** Force-stopping
  `com.vivo.cardstore` also killed `com.android.launcher3`
  (`am_kill … stop com.vivo.cardstore`). SystemUI restarted it right away by
  rebinding `TouchInteractionService`.

**Root cause: not established.** Working theory: the gesture service sometimes
binds to its own home before Nova is available at boot and keeps using it
until the vivo launcher process restarts.

### Change applied

```sh
adb shell cmd package set-home-activity --user 0 com.teslacoilsw.launcher/.NovaLauncher
```

This writes Nova as the persistent preferred `MAIN/HOME` activity (visible in
`dumpsys package preferred-xml`), on top of the HOME role. Undo by choosing
another home app in Settings → Apps → Default apps → Home app.

### Not possible without root

- `pm disable --user 0 com.android.launcher3/.Launcher` (or the
  `com.bbk.launcher2.Launcher` component): `SecurityException: Shell cannot
  change component state`. AOSP only lets the shell toggle whole packages.
- `pm disable-user com.android.launcher3`: blocked by vivo
  (`no root permission`). It would also take out recents and gestures.

### If it comes back

1. Reconnect ADB and check `ps -o PID,STIME,NAME -p $(pidof com.android.launcher3)`
   against the unlock time.
2. Restart the gesture service with `adb shell am force-stop
   com.android.launcher3`. SystemUI rebinds it immediately; this is untested
   as a fix.
3. Ways to try without ADB (untested): re-pick Nova under Default apps →
   Home app, or switch navigation to 3 buttons and back to gestures.
4. Fallback: 3-button navigation. The Home key always launches the default
   HOME activity.

## Root — assessed 2026-10-29: not possible

- **Bootloader:** locked (`ro.boot.flash.locked=1`,
  `ro.boot.vbmeta.device_state=locked`, verified boot `green`). vivo/iQOO
  offer no official unlock in any region, and the pre-May-2022 methods don't
  apply to this device (first API level 34).
- **Locked-bootloader exploit root:**
  [RootMyVivo](https://github.com/zenyxx-xd/RootMyVivo) uses CVE-2026-43499.
  It only covers kernels 6.1 up to 6.1.144. This phone runs **6.1.145**
  (September 2026 patch), and the I2220 isn't on its device list. The root it
  gives disappears at every reboot.
- **Cost even if possible:** the banking/UPI apps, Google Wallet and Okta/Duo
  rely on Play Integrity.
- Reference:
  [bootloader-unlock-wall-of-shame — vivo](https://github.com/zenfyrdev/bootloader-unlock-wall-of-shame/blob/main/brands/vivo/README.md).
