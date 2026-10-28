# TP-Link ER605 v2 "rigwarl"

A TP-Link ER605 v2 running OpenWrt, hostname `rigwarl`. It sits on the home LAN
behind the Airtel XX530v and does five jobs:

- 5-port Gigabit switch
- Tailscale subnet router for `10.10.1.0/24` and exit node
- DNS ad blocking and local `*.lan` names for the whole house
- Device watchdog with phone alerts (ntfy)
- On-demand iperf3 server for Wi-Fi speed tests

This repository is public. The root password, the ntfy topic and access token,
the old PPPoE login and the config backups are kept only in the gitignored
`devices/private/tp-link-er605/` folder.

## At a glance — 2026-10-29

| Item | Value |
| --- | --- |
| Hardware | MT7621 (2 × 880 MHz MIPS), 256 MB RAM, 128 MB NAND (~87 MB free for config and packages) |
| Firmware | OpenWrt 25.12.6, kernel 6.12.112. Custom image built by `owut` that includes Tailscale |
| LAN | `10.10.1.101/24` static, gateway `10.10.1.1` (XX530v). IPv6 address by DHCPv6 from the XX530v |
| MAC | `24:2F:D0:…:B9` (TP-Link) |
| Ports | All five ports, including the one labelled WAN, are one bridge (`br-lan`). Use any of them |
| DHCP / RA | Off. The XX530v is the only DHCP server |
| Web UI | LuCI at `http://10.10.1.101` or `http://rigwarl.lan` |
| SSH | `ssh root@10.10.1.101` (Dropbear, SFTP available for WinSCP) |
| Tailscale | 1.104.1, machine `rigwarl`. Route `10.10.1.0/24` and exit node approved, key expiry disabled |

```text
Airtel fibre ── XX530v (10.10.1.1, gateway + DHCP)
                  │
            dumb switch ── rigwarl (10.10.1.101) ── ports 2–5: anything wired
                  │              ▲
              other LAN          └── Tailscale: phone/laptop anywhere → 10.10.1.0/24
```

Internet traffic from the house goes straight to the XX530v; it does not pass
through rigwarl. Only Tailscale traffic (remote access, exit node) and DNS
queries go to rigwarl.

## Configuration

[`rigwarl-clean.sh`](rigwarl-clean.sh) resets the config to stock OpenWrt and
applies the base setup. [`rigwarl-services.sh`](rigwarl-services.sh) adds the
services. Both run on the router. Together they change the following from stock.

**Network** (`/etc/config/network`)

- `br-lan` bridges `lan2`–`lan5` and `wan1`.
- `lan`: static `10.10.1.101/24`, gateway and DNS `10.10.1.1`.
- `lan6`: DHCPv6 client on `br-lan` that requests an address but no prefix. The
  exit node needs a public IPv6 address to forward IPv6.
- `tailscale`: unmanaged interface on `tailscale0`.
- No `wan`/`wan6` interfaces. The PPPoE config from the old router role is gone.

**DHCP and DNS** (`/etc/config/dhcp`)

- LAN DHCP, DHCPv6 and router advertisements are off.
- dnsmasq answers LAN and Tailscale clients (`localservice 0`) and resolves
  upstream directly via Cloudflare (`1.1.1.1`, `1.0.0.1`,
  `2606:4700:4700::1111`, `::1001`, `noresolv 1`).
- `domain` entries give the local names listed under [Services](#ad-blocking-and-local-names).

**Firewall** (`/etc/config/firewall`)

- Stock zones and rules, plus a `tailscale` zone (input, output and forward
  accepted) with forwardings `tailscale → lan` and `lan → tailscale`.
- `Allow-Tailscale-IPv6` accepts UDP 41641 over IPv6 (direct Tailscale
  connections). `Block-nonlocal-IPv6-to-router` then drops every other TCP and
  UDP connection to rigwarl itself from a non-link-local IPv6 address.
- The second rule exists because rigwarl has a public IPv6 address and the
  `lan` zone accepts input. Without it, SSH and LuCI would rely only on the
  XX530v's IPv6 firewall. Management stays on IPv4 and Tailscale. Forwarded
  exit-node traffic is unaffected. Verified 2026-10-29 from another LAN host:
  22/80/443 over IPv6 blocked, IPv4 open.

**Tailscale**

```sh
tailscale up --hostname=rigwarl --advertise-routes=10.10.1.0/24 --accept-routes=false --accept-dns=false
tailscale set --auto-update=false --advertise-exit-node
```

- Approve the route and exit node and disable key expiry in the admin console.
- `--auto-update=false` is required. The OpenWrt build cannot self-update, and
  while the preference is on, every `tailscale set` fails with *Auto-update
  support is disabled in this build*.
- Login state lives in `/etc/tailscale/` and survives sysupgrades.

**Scheduled jobs** (`/etc/crontabs/root`)

| When | Job |
| --- | --- |
| Every 10 minutes | `homewatch.sh` device watchdog |
| Sunday 04:00 | `apk update && apk upgrade`: package updates, including Tailscale. Log: `/tmp/apk-auto-upgrade.log` |

`/etc/rc.local` sends a "rigwarl started" alert two minutes after boot, so a
power cut or crash shows up on the phone.

## Services

### Ad blocking and local names

`adblock-fast` loads the [Hagezi Multi Normal](https://github.com/hagezi/dns-blocklists)
list into dnsmasq: about 172,000 domains (ads, trackers, malware, phishing).
It also blocks `use-application-dns.net`, the canary domain that tells Firefox
to turn off its own DNS-over-HTTPS. Manage it in LuCI under **Services →
AdBlock-Fast** (pause, allow a domain, change lists).

The XX530v's DHCP server hands out `10.10.1.101` as the only DNS server (it was
`1.1.1.1` / `8.8.8.8` before 2026-10-29). Known gaps:

- The XX530v also advertises itself (`fe80::1`) as an IPv6 DNS server. Devices
  with IPv6 send some queries there, unfiltered. Changing it means editing the
  PPPoE WAN connection on the XX530v, whose form shows blank password fields.
  That was left alone.
- Devices with DNS set by hand (the TITAN desktop) don't use rigwarl until
  changed.
- If rigwarl is down, IPv4-only devices (Tapo plugs) lose DNS. Devices with
  IPv6 still resolve through the XX530v.

Local names (`<name>.lan`):

| Name | Address |
| --- | --- |
| `router`, `xx530v` | 10.10.1.1 |
| `titan` | 10.10.1.10 |
| `santa` | 10.10.1.20 |
| `lanaya` | 10.10.1.30 |
| `tv`, `lg-nunu` | 10.10.1.35 |
| `tapo-plug-1`, `tapo-plug-2` | 10.10.1.50, 10.10.1.51 |
| `hall-ap`, `archer-c6` | 10.10.1.100 |
| `rigwarl` | 10.10.1.101 |
| `aruna-206` | 10.10.1.150 |

To get ad blocking and these names over Tailscale, add `10.10.1.101` as a
nameserver in the Tailscale admin console under **DNS**. Either enable
**Override DNS servers** (blocking everywhere) or restrict it to the domain
`lan` (names only).

### Device watchdog (homewatch)

Files in `/etc/homewatch/` (listed in `/etc/sysupgrade.conf`, so they survive
upgrades). The repository copies are in [`homewatch/`](homewatch/).

| File | Purpose |
| --- | --- |
| `homewatch.sh` | One check pass (cron); `boot` sends the restart alert; `status` prints each host's state |
| `hosts` | Devices to watch: `address name`. `#` disables a line. Several addresses separated by commas count as up if any answers |
| `homewatch.conf` | `NTFY_URL` (topic), `NTFY_AUTH` (optional access token), `INTERVAL_MIN`, `FAILS_BEFORE_DOWN`. Router-only, never commit |
| `history.log` | Every alert, kept to the last 1,000 lines |

- Each pass pings every host (3 pings, 2 s timeout). A host is marked down
  after `FAILS_BEFORE_DOWN` failed passes, which sends "… is down". When it
  answers again, "… is back online after Xh Ym" follows.
- Alerts that can't be sent (internet down) are queued in `/tmp/homewatch/queue`
  and sent on the next pass.
- Prefix an address with `arp:` for devices that ignore ping. Aruna-206 is a
  D-Link router whose WAN side faces this LAN and drops ping. The check clears
  the neighbour entry, sends one ping and counts a fresh ARP reply as up.
  BusyBox has no `arping`.
- Current setting: only `arp:10.10.1.150 aruna-206`, every 10 minutes, one
  failed pass = down. The other devices are in `hosts`, commented out.
- Alerts go to ntfy.sh. The topic name is random and the only protection, since
  topic reservation is a paid ntfy feature. `NTFY_AUTH` signs alerts with the
  owner's access token: base64url of `Bearer tk_…`, without padding, sent as
  the `auth` query parameter because `uclient-fetch` cannot set headers.

### Wi-Fi speed test

`/etc/homewatch/wifitest.sh start` runs an iperf3 server on `10.10.1.101:5201`
for 30 minutes, then it stops by itself. `stop` ends it early. Nothing runs
until started. LuCI **System → Custom Commands** has buttons for start, stop
and the watchdog status. Test from a phone with an iperf3 client (Android:
Magic iPerf; iOS: HE.NET Network Tools). Expect rigwarl's CPU to cap results
somewhere around 400–600 Mbps.

## Maintenance

**Firmware upgrades** stay manual. LuCI flags new releases on the Status page.
`owut` builds an image that keeps every installed package:

```sh
owut check                                  # read-only pre-flight
owut download --version-to <version>        # build on sysupgrade.openwrt.org, save /tmp/firmware.bin
sysupgrade -T /tmp/firmware.bin             # validate
sysupgrade -v /tmp/firmware.bin             # run in the foreground; settings are kept
```

Run `sysupgrade` in the foreground. A command left running in the background
of an SSH session is killed when the session closes, so the upgrade never
starts. The router is back in about 75 seconds. 24.10.0 → 25.12.6 on 2026-10-29
kept the Tailscale login, routes and all settings. That upgrade also needed
`kmod-crypto-hw-eip93` (`--add`), a 25.12 default for this board.

**Config backups**: `sysupgrade -b /tmp/backup.tar.gz`, copied to
`devices/private/tp-link-er605/backups/` after each change. The archives
contain the root password hash, SSH host keys, the Tailscale node key and the
ntfy token.

**Rebuilding from scratch** (new OpenWrt install, or after `firstboot`):

1. Connect a PC to a LAN port only. A fresh install runs a DHCP server on
   `192.168.1.1`, so keep it off the home network.
2. Install `tailscale` and `owut`, then copy `rigwarl-clean.sh` and run it
   detached (`start-stop-daemon -S -b -x /bin/sh -- /tmp/rigwarl-clean.sh`): the
   network reload drops the SSH session. Set the hostname to `rigwarl`.
3. Move the uplink cable to any port and reconnect at `10.10.1.101`.
4. Copy `homewatch/` to `/etc/homewatch/`, run `rigwarl-services.sh`, and
   restore `homewatch.conf` from a private backup to keep the same ntfy topic.
5. Run the two Tailscale commands above, then approve the route and exit node.

## Troubleshooting notes — 2026-10-29

| Symptom | Cause / fix |
| --- | --- |
| `apk update`: *Failed to send request: Operation not permitted* | DNS on the router was down. dnsmasq was crash-looping on *DHCP host has multiple names*, from static leases left over from the old main-router config, which 25.12's dnsmasq rejects. Removing them fixed it. Check with `logread \| grep dnsmasq` |
| `tailscale set` fails: *Auto-update support is disabled in this build* | Run `tailscale set --auto-update=false` together with the change |
| `start-stop-daemon`: *already running* | It matches any process with the same executable, e.g. another `/bin/sh`. Give the job its own pidfile: `-m -p /var/run/<name>.pid` |
| Missing `timeout`, `arping`, `comm` | This BusyBox build leaves them out; the scripts work around them |
| LuCI answers 403 | Normal before login: the 403 page is the login form |
| adblock-fast warns gawk, grep, sed and coreutils-sort are missing | Optional speed-ups for the daily list rebuild; blocking works without them |
| Watchdog reports a router as down, but it is online | The device drops ping. Use the `arp:` prefix |

To reach a box whose LAN address clashes with the XX530v (this one used
`10.10.1.1` in its old role): connect it to a spare NIC, let it hand out an
address, and bind the connection to that NIC's address, e.g. a socket bound to
the NIC's IP before connecting. IPv6 link-local (`fe80::…%<if>`) also works
when IPv4 is unusable.

## History

- **2025:** main router behind Airtel (PPPoE, OpenWrt 23.05 → 24.10), with
  adblock-lean, DNS-over-HTTPS (`https-dns-proxy`), SQM and Tailscale as an
  exit node.
- **2026-10-29:** repurposed after the XX530v took over:
  - LAN moved from `10.10.1.1` to `10.10.1.101`, PPPoE disabled and then
    removed, all ports bridged.
  - Upgraded 24.10.0 → 25.12.6.
  - Leftovers removed: 9 static leases, adblock-lean cron and helpers,
    https-dns-proxy, SQM config, iptables-nft modules, Lua LuCI compatibility.
  - Ad blocking, local names, homewatch and the Wi-Fi test server added.
  - The original flashing guide and its scripts were removed from this folder;
    they are in git history.

## Initial OpenWrt install

The ER605 v2 needs a one-time conversion from TP-Link firmware: SSH debug
access, an initramfs written to the UBI kernel volumes, then a sysupgrade. See
the [OpenWrt wiki page](https://openwrt.org/toh/tp-link/er605_v2) and the
[installer by chill1Penguin](https://github.com/chill1Penguin/er605v2_openwrt_install).
Back up the full flash (`mtd`) before converting.
