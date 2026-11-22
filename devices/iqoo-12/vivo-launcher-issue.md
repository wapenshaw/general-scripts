# Issue: swipe-up home sometimes shows the vivo launcher — 2026-10-29

## Symptom

With Nova set as the default home app and gesture navigation on, swiping up
to go home sometimes showed the stock vivo launcher instead of Nova. The user
tied it to restarts.

## Findings

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

## Change applied

```sh
adb shell cmd package set-home-activity --user 0 com.teslacoilsw.launcher/.NovaLauncher
```

This writes Nova as the persistent preferred `MAIN/HOME` activity (visible in
`dumpsys package preferred-xml`), on top of the HOME role. Undo by choosing
another home app in Settings → Apps → Default apps → Home app.

## Not possible without root

- `pm disable --user 0 com.android.launcher3/.Launcher` (or the
  `com.bbk.launcher2.Launcher` component): `SecurityException: Shell cannot
  change component state`. AOSP only lets the shell toggle whole packages.
- `pm disable-user com.android.launcher3`: blocked by vivo
  (`no root permission`). It would also take out recents and gestures.

## If it comes back

1. Reconnect ADB and check `ps -o PID,STIME,NAME -p $(pidof com.android.launcher3)`
   against the unlock time.
2. Restart the gesture service with `adb shell am force-stop
   com.android.launcher3`. SystemUI rebinds it immediately; this is untested
   as a fix.
3. Ways to try without ADB (untested): re-pick Nova under Default apps →
   Home app, or switch navigation to 3 buttons and back to gestures.
4. Fallback: 3-button navigation. The Home key always launches the default
   HOME activity.

