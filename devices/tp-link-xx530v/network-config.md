# XPON registration

| Setting | Value |
| --- | --- |
| SN format | ASCII+HEX |
| GPON SN | `NKOTxxxxB454`, from the back label of the Airtel-supplied Nokia ONT (not this router's own SN) |
| GPON password type / value | ASCII, empty |
| OLT mode | **Mode X** |

Airtel supplied a locked Nokia ONT and its OLT only authorises that unit's
serial. This TP-Link replaces it by presenting the Nokia's GPON SN, so a
replacement or factory-reset router needs that SN re-entered before the WAN
connections come up.

## WAN connections

| Setting | `Airter_Xstream` (internet) | `AirtelVoip` (voice) |
| --- | --- | --- |
| Service type | Internet | Internet, VoIP |
| VLAN ID | **100** | **660** |
| 802.1p priority | 0 | **4** |
| Multicast VLAN | 0 | 0 |
| Connection type | **PPPoE** | **Static IP** |
| PPPoE username | `0401xxxxxx64_ap@airtelbroadband.in` | — |
| PPPoE password | `2000xxxxx84` | — |
| Authentication | `AUTO_AUTH`, connection mode Auto | — |
| IPv4 address | Assigned by PPPoE | `10.54.211.161` / `255.255.248.0` |
| IPv4 gateway | — | `10.54.208.1` |
| DNS | — | `1.1.1.1`, `8.8.8.8` |
| Default gateway | `pppoe_gpon_100…` | `pppoe_gpon_100…` |
| IPv6 | Enabled, **DHCPv6**, gateway Auto | Disabled |
| IPv6 tunnel | Disabled | Disabled |
| MAC clone | — | Do not clone |

The PPPoE credentials come from the **Airtel Thanks** app, under Account info:

- **Username:** the **DSL Number** (`0401xxxxxx64_ap`; `_ap` is the state
  code), then `@airtelbroadband.in`.
- **Password:** the **Account Number** (`2000xxxxx84`).

The connection name `Airter_Xstream` is spelled that way on the router.

## Static routing (IPv4)

| ID | Destination | Mask | Gateway | Enabled |
| --- | --- | --- | --- | --- |
| 1 | `10.5.0.0` | `255.255.0.0` | `10.54.208.1` | Yes |

This sends `10.5.0.0/16`, presumably Airtel's voice network, out the VoIP
connection rather than the PPPoE default route.

## LAN addressing — 2026-10-25

LAN `10.10.1.0/24`, router `10.10.1.1`, lease 240 min, DNS `10.10.1.101` (rigwarl, ad blocking;
`1.1.1.1` / `8.8.8.8` before 2026-10-29).
The DHCP pool was moved from `.2–.249` to **`.151–.249`** so it no longer
overlaps addresses that devices set by hand. Fixed addresses are listed below.
MACs are masked; full values, the pre-change client list and before/after
config backups are in the local-only
[LAN client log](../private/tp-link-xx530v/lan-clients-2026-10-25.md).

| IP | Device | MAC (masked) | Reservation | IP & MAC binding |
| --- | --- | --- | --- | --- |
| .10 | TITAN desktop | `04:7C:16:…:9A` (MSI) | yes | yes |
| .25 | iQOO 12 phone (device MAC on `Nunu`; added 2026-11-07) | `00:9C:C0:…:19` | yes | yes |
| .35 | LG-Nunu | `B4:B2:91:…:54` (LG) | yes | yes |
| .50, .51 | Tapo P110 smart plugs | `5C:E9:31:…:7D`, `20:23:51:…:5B` (TP-Link) | yes | yes |
| .100 | TP-Link-Hall access point | `1C:3B:F3:…:FC` (TP-Link) | yes | yes |
| .101 | rigwarl: ER605 v2 (OpenWrt 25.12): switch, Tailscale subnet router and exit node, LAN DNS with ad blocking; static on the device, DHCP/RA off. See [er605-openwrt](../../er605-openwrt/README.md) | `24:2F:D0:…:B9` (TP-Link) | no | no |
| .150 | Aruna-206: D-Link downstream router (grandmother's house) | `70:62:B8:…:4A` (D-Link) | yes | yes |

Ranges: `.2–.49` PCs, phones, Apple devices and TV; `.50–.99` IoT; `.100–.150`
network equipment; `.151–.249` dynamic.

**IP & MAC Binding** (Advanced → Security) is enabled. It pins the router's
ARP entries against spoofing. The firmware rejects a DHCP reservation whose MAC
is bound to a different IP (error 5047), so the two lists must agree. Editing a
binding in place fails with error 5401 and can leave a duplicate entry. Delete
the old binding and add a new one instead.

Only globally unique (vendor) MACs are pinned. Devices using locally
administered (randomized) MACs (second hex digit 2, 6, A or E), such as santa
and the Mac, were deliberately unpinned because their MAC can
change and silently orphan the entry. They take pool addresses (or keep an
address set on the device). To pin one, switch it to its hardware MAC for this
network first, then add both a reservation and a binding. The iQOO 12 was
switched this way on 2026-11-07 and pinned at .25.

## Wi-Fi channels — 2026-10-29

One SSID, `Nunu`, on every radio. Channels are fixed so the two access points
never overlap.

| Radio | Band | Channel | Width |
| --- | --- | --- | --- |
| XX530v | 5 GHz | 36 (spans 36–64) | 160 MHz |
| XX530v | 2.4 GHz | off (keep it off) | — |
| Archer C6 (hall AP, `.100`) | 5 GHz | 149 (spans 149–161) | 80 MHz |
| Archer C6 (hall AP, `.100`) | 2.4 GHz | 1 | 20 MHz |

The C6's Smart Connect is off, because the firmware hides channel settings
while it is on. Both of its bands keep the same SSID and password. EasyMesh and
UPnP are off.

160 MHz raised santa's link rate from about 1200 to 1920 Mbps, and iperf3 to
TITAN from about 460 to about 800 Mbps. Channels 52–64 are DFS (shared with
radar), so the XX530v must leave them for about a minute if it detects radar.
If drops become a problem, go back to 80 MHz on channel 36. Measure Wi-Fi with
iperf3 against TITAN (`iperf3 -s`), not rigwarl: rigwarl's CPU caps its test
server at about 450 Mbps.

