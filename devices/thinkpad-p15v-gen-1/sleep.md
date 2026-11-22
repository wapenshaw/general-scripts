# Sleep policy and waking

GNOME suspends on idle per power source. The logged-in user's setting alone does not
cover the login screen or the lid, so three places are set.

| Surface | Where | AC | Battery |
| --- | --- | --- | --- |
| Logged-in session | `gsettings` `sleep-inactive-*-type` | `nothing` (already default here) | `suspend`, 900 s |
| GDM login screen | `/etc/dconf/db/gdm.d/10-power`, then `sudo dconf update` | `nothing` | default |
| Lid close | `/etc/systemd/logind.conf.d/10-ac.conf` | `ignore` | `suspend` (default) |

`/etc/dconf/db/gdm.d/10-power`:

```ini
[org/gnome/settings-daemon/plugins/power]
sleep-inactive-ac-type='nothing'
sleep-inactive-ac-timeout=0
```

`/etc/systemd/logind.conf.d/10-ac.conf`:

```ini
[Login]
HandleLidSwitchExternalPower=ignore
```

Apply logind changes with `sudo systemctl kill -s HUP systemd-logind`, not a
restart. The GDM change takes effect when the greeter next starts. A closed lid on
AC with sleep disabled can overheat in a bag.

Check:

```sh
busctl get-property org.freedesktop.login1 /org/freedesktop/login1 \
  org.freedesktop.login1.Manager HandleLidSwitchExternalPower   # s "ignore"
k=sleep-inactive-ac-type
s=org.gnome.settings-daemon.plugins.power
sudo -H -u gdm env DCONF_PROFILE=gdm gsettings get $s $k         # 'nothing'
```

Run the `gdm` check as the `gdm` user. Your own user already reports `'nothing'`, so
checking as `heaton` proves nothing about the greeter. Verified 2026-11-22: the lid
property reads `ignore`, and the `gdm`-user readback returns `'nothing'`.

## Waking a sleeping laptop

SSH cannot wake a suspended machine, because no network stack runs during suspend.
Only a Wake-on-LAN magic packet can. This is moot on AC with sleep disabled, but
applies on battery.

| Interface | State |
| --- | --- |
| Ethernet `enp0s31f6` (e1000e, MAC `38:f3:ab:43:b8:e6`) | PCI wakeup enabled; no cable, so no carrier |
| Wi-Fi `wlp0s20f3` (iwlwifi, MAC `4c:79:6e:72:8c:65`), profile `Nunu` | Supports wake on magic packet; WoWLAN **disabled**, not changed |

To enable WoWLAN, run these **from the local console**. Reactivating the only Wi-Fi
link drops any SSH session over it:

```sh
nmcli connection modify Nunu 802-11-wireless.wake-on-wlan magic
nmcli connection up Nunu
iw phy phy0 wowlan show
```

A sleeping Wi-Fi client only wakes if the access point holds the packet, so this is
unreliable. [INFERENCE] Not tested here. A cabled Ethernet connection with
`802-3-ethernet.wake-on-lan magic` is the dependable route.
