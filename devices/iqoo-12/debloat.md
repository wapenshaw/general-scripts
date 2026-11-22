# Debloat — 2026-10-29

Removed with `pm uninstall -k --user 0`, so the APKs stay on `/system` and
every removal is reversible. Package lists from before and after, plus the
command log, are in `private/iqoo-12/`.

## Already removed before this session (30)

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

## Uninstalled for user 0 (28)

| Group | Packages |
| --- | --- |
| vivo promo / ecosystem | `com.vivo.hybrid` (Quick Apps), `com.vivo.game` (Game Center), `com.vivo.unionpay`, `com.vivo.vhome`, `com.vivo.tws.vivotws`, `com.vivo.easyshare` |
| vivo launcher widgets | `com.vivo.countdownwidget`, `com.vivo.timerwidget`, `com.vivo.doubletimezoneclock`, `com.vivo.musicmixcard`, `com.vivo.widget.cleanspeed`, `com.vivo.healthwidget` |
| vivo utilities | `com.vivo.weather`, `com.vivo.widgetweather`, `com.vivo.compass`, `com.vivo.calculator`, `com.vivo.stepcount`, `com.vivo.smartanswer` |
| Google | `com.android.chrome`, `com.google.android.apps.messaging`, `com.google.android.apps.bard` (Gemini), `com.google.android.projection.gearhead` (Android Auto), `com.google.android.apps.tachyon` (Meet), `com.google.android.apps.restore`, `com.google.android.apps.setupwizard.searchselector`, `com.google.android.printservice.recommendation` |
| AOSP extras | `com.android.email.partnerprovider`, `com.android.egg` |

## Protected by vivo — restricted instead (13)

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

## Deliberately kept

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

## Undo

```sh
adb shell cmd package install-existing <pkg>                # uninstalled packages
adb shell cmd appops set <pkg> RUN_ANY_IN_BACKGROUND allow  # restricted packages
adb shell cmd appops set <pkg> RUN_IN_BACKGROUND allow
adb shell pm grant <pkg> android.permission.POST_NOTIFICATIONS
```

After the changes there were no entries in the crash buffer. Settings and
Nova kept working.

