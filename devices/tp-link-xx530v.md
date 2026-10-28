# TP-Link XX530v (Airtel Xstream fibre modem)

Last inspected: **2026-10-25**, from web UI screenshots, the label photo,
local backup/firmware analysis, live SSH/Telnet checks and OpenWrt research.

This repository is public, so the GPON SN and PPPoE credentials below are
masked. Each one says where to read the full value.

## Findings summary — 2026-10-25

| Area | Result |
| --- | --- |
| Backup recovery | Decrypted locally with a firmware-derived DES key; embedded MD5 verified; analysis XML parsed successfully |
| Backup age | Backup reports build **250422**; installed/saved firmware is recorded as **251126** |
| SSH password | Recovered `user` credentials authenticate at `10.10.1.1:22`; this does **not** provide shell access |
| SSH sessions | Commands, interactive PTY/shell and SFTP each fail with `Channel closed` |
| SSH public key | Existing `id_ed25519_xx530v` key rejected; no key installed on the router |
| Telnet | Recovered password opens a restricted `TP-Link>` CLI on LAN port 23; `help` works |
| Firmware restrictions | Saved build disables management SSH, web Telnet controls and the CLI `sh` command |
| Web UI | Screenshot confirms HTTP/HTTPS management controls only; no SSH/Telnet toggle |
| OpenWrt | Experimental XX530v v1 support exists, but documented GPON/EPON and phone-port support are missing |
| Changes to router | LAN/DHCP only (2026-10-25): DHCP pool, reservations and IP & MAC bindings reorganised; see [LAN addressing](#lan-addressing--2026-10-25). No key installation, restore, reboot or flashing |

Keep the current firmware for the active Airtel fibre/voice connection. Key-based
shell access has no verified setup path on this build. OpenWrt is a possible
hardware investigation, with exact-board checks and a full NAND backup required
before considering installation. A full security/configuration audit and current
TR-069 state verification remain outstanding.

## Device

| Item | Value |
| --- | --- |
| Manufacturer | TP-Link (Aginet) |
| Model | **XX530v**, AX3000 dual-band Wi-Fi 6 GPON router |
| Hardware version | **XX530v v1.0 00000001** (web UI); label reads **IN/1.8** |
| Serial number | `225472…` (full value in private credentials) |
| Router's own GPON SN | `TPLG…` |
| MAC | `A8-29-48-…-40` |
| Default SSID | `TP-Link_8740` |
| Made in | India |
| ISP | Airtel Xstream Fiber |

## Firmware

| Item | Value |
| --- | --- |
| Installed (2026-10-25) | **0.9.0 3.0.0 v6096.0 Build 251126 Rel.13993n** |
| Kept image | `XX530vv1_0.9.0_3.0.0_UP_BOOT_agc3000(251126)_2025-11-26_13.40.50.bin` |
| Build date | 2025-11-26 |
| SHA-256 (`.bin`) | `609733dd67b71e62c98daef963df464c0ecfddecb90a6ef77d0b5a2413a56626` |
| SHA-256 (`.rar`) | `fcf40b697bfdffea6e5cf98770931943b03a0ecf031eee1496cb2e6ec9e7b35e` |

The installed build recorded from the web UI (**251126**) matches the kept
image. However, the decrypted config backup identifies **0.6.0 3.0.0 v6096.0
Build 250422 Rel.46744n**. The earlier assumption that the backup came from
build 251126 was incorrect. Treat it as a historical configuration snapshot.
**Advanced → System Tools → Firmware Upgrade** shows the current version;
check firmware compatibility before restoring this backup.

## SSH authentication and session restrictions — 2026-10-25

Password authentication succeeded at **10.10.1.1:22** with username **`user`**
and the password recovered from the backup. The following command reaches the
SSH service, but a usable shell session is **not** available:

```powershell
ssh -o NumberOfPasswordPrompts=1 user@10.10.1.1
```

The password is in the local-only
[SSH findings](private/tp-link-xx530v/ssh-findings.private.md). This link and
the other private links below only work on a PC holding those gitignored files.

- The owner had already tried `admin` and `root` with the web UI and suggested
  default passwords; those attempts failed.
- The backup contains `admin` and `user` account entries, with `user` enabled
  and `X_TP_UserCfg/AdminEnable=0`. The latter may explain the failed `admin`
  login; it does not establish the current router's complete access policy.
- No root credentials or explicit `SSHCfg`/`TelnetCfg` overrides were present
  in the backup. No hidden ISP login was established by this investigation.
- Verification used Paramiko and checked the server key against the existing
  local SSH `known_hosts`. The initial check authenticated once and disconnected;
  subsequent authenticated checks tested command, shell and SFTP requests.
  No password guessing or brute-force attempts were performed.

### Key-login follow-up — 2026-10-25

The existing local Ed25519 key pair is `~/.ssh/id_ed25519_xx530v` and
`~/.ssh/id_ed25519_xx530v.pub`. A public-key-only test with that identity was
rejected. The private key was not copied to the router.

Further password-authenticated connections identified the live SSH server as
`dropbear_2020.80`, but **command execution, an interactive PTY/shell, and the
SFTP subsystem each failed with `Channel closed`**. Successful password
authentication therefore does not currently provide a usable management shell.
No public key was installed and no router settings were changed.

Upstream [Dropbear](https://github.com/mkj/dropbear/blob/main/README.md) supports
public keys in the account's `~/.ssh/authorized_keys`, with permissions that
prevent other users from writing the directory/file. Applying that mechanism
here requires a supported way to write the file and confirmation of the
account's actual home directory and storage persistence. These are not yet
established. The usual `ssh-copy-id` or SSH command pipeline cannot work through
the currently rejected command/shell channels.

## Telnet and firmware management features — 2026-10-25

LAN TCP port 23 was reachable. Telnet presented a password-only prompt and
accepted the recovered `user` password. Its `TP-Link>` interface returned these
normal-mode commands for `help`: `clear`, `exit`, `help`, `history`, `logout`,
and `wlctl`. This established access to a restricted vendor CLI, not a Linux
shell. Only login and `help` were performed; the connection was then closed.
Telnet is unencrypted and should only be used on the trusted LAN.

The owner's screenshot of Local/Remote Management shows HTTP/HTTPS controls
but no SSH or Telnet controls. Inspection of `etc/config.bba` in the saved build
251126 firmware explains their absence:

```text
INCLUDE_CLI_FULL_FEATURE=y
# INCLUDE_CLI_CMD_SH is not set
# INCLUDE_CLI_CMD_DUMP_OID is not set
# INCLUDE_CLI_ENC_CMD_DEBUG is not set
# INCLUDE_WEB_TELNET is not set
# INCLUDE_REMOTE_TELNET is not set
# INCLUDE_SSH_ACCESS is not set
```

Management SSH and the Telnet CLI's `sh` command are disabled in this saved
firmware's build configuration. The shared `web/main/manageCtrl.htm` source
contains SSH/Telnet controls gated by build flags, including `INCLUDE_SSH_ACCESS`.
Their presence in shared source did not establish availability on this device.
The earlier suggestion to find an SSH toggle was superseded by this build check.
Changing HTTPS or WAN remote-management settings will not provide SSH shell
access. Merely unhiding page controls does not add omitted firmware features.

There is currently no verified supported route to install an authorized key for
shell login on this build. A firmware variant explicitly supporting management
SSH/shell access would need confirmation from TP-Link for this exact hardware
and ISP setup. The experimental OpenWrt option below has not been validated on
this particular board. No flashing, config restore or device modification was
attempted.

## OpenWrt assessment — 2026-10-25

The [OpenWrt XX230v/XX530v v1 page](https://openwrt.org/inbox/toh/tp-link/xx230v_v1)
explicitly includes **XX530v v1**, despite its XX230v URL. It describes an
experimental downstream build: **GPON/EPON is unsupported and the FXS phone
port has no driver**. Its installation procedure requires serial-console access,
replacement of the stock U-Boot and repartitioning flash. This is not a stock
web-interface upgrade. The
[development PR #20104](https://github.com/openwrt/openwrt/pull/20104) was still
draft when checked, with xPON, OMCI and VoIP work listed as unfinished.

For this installation, those limitations mean OpenWrt cannot currently be
relied on to replace the TP-Link's direct Airtel fibre connection or phone-port
service. Re-entering the GPON serial and PPPoE credentials does not supply the
missing drivers. Treat a future conversion as an Ethernet/Wi-Fi experiment
after a separate ONT provides the fibre connection.

### Hardware evidence and unresolved compatibility

| Item | Saved firmware evidence | Implication |
| --- | --- | --- |
| Platform | `SDK_DIR="en7529"`, EN7523-family SDK configuration | Consistent with the family documented by the port; exact board not physically verified |
| Flash | `INCLUDE_FLASH_SPINAND=y`, `INCLUDE_FLASH_128M=y` | Consistent with the documented 128 MiB NAND family |
| Boot allocation | `MTD_BOOT_SIZE="0xa0000"` (**640 KiB**) | Differs from the wiki's **512 KiB** stock boot-partition example; actual partition boundaries require verification |
| Hardware revision | Label **IN/1.8**, UI **v1.0 00000001** | Regional board compatibility remains unconfirmed |

The build settings are evidence from the saved vendor image, not a live NAND
partition dump. Do not reuse the wiki's flash offsets without checking the
actual device. The downstream build/release host could not be opened during
research; no OpenWrt image was downloaded or independently validated.

### Next steps if pursuing the hardware experiment

1. Arrange a working alternative fibre/voice setup before taking this router
   out of service.
2. Inspect the board and identify its UART pins and electrical requirements;
   use a suitable serial adapter to capture the boot log without writing flash.
3. Establish the real flash layout, capture and verify a **full NAND backup**
   including device-specific data, and establish a recovery method. The existing
   web configuration backup and vendor firmware image are not a full NAND dump.
4. Confirm the exact hardware revision and image compatibility before deciding
   whether to replace U-Boot or repartition. A factory reset cannot undo those
   changes.

None of these hardware steps has been performed. The current outcome is an
assessment, not approval or preparation to flash the active router.

## Local backup recovery — 2026-10-25

All backup processing took place on this PC under `devices/private/tp-link-xx530v/`.
The backup and recovered configuration were not uploaded. Network access was
used to read public tool documentation, download the decoder and Python
dependencies, and perform the local router authentication check.

### Method and validation

1. Confirmed that `devices/private/` is covered by `.gitignore`.
2. Downloaded and inspected
   [tpconf_bin_xml.py](https://github.com/sta-c0000/tpconf_bin_xml), version
   **0.2.15**. Installed `pycryptodomex` in the private `python-deps/` directory
   using `uv`, with its cache also inside the private folder. All seven built-in
   keys, including the EX530v key, failed to decode this XX530v backup.
3. Used 7z/NanaZip to inspect the saved build 251126 firmware locally. Its
   SquashFS filesystem starts at byte **3140420**. Extracted selected libraries,
   configuration files and login-related binaries into `firmware-inspect/`.
   Additional local inspection dependencies were `pyelftools` and `capstone`.
4. Followed the
   [firmware backup-key analysis](https://github.com/jqssun/tplink-firmware-tools#converting-backup-configuration-_backupcfgbin).
   Located the base-key bytes beside the `Get dev info for BNR key failed`
   message in `lib/libcmm.so`. Decrypted the firmware's default configuration
   and reduced data model with their separate published DES key. The reduced
   model identifies `X_TP_ProductID=0x5133d101`.
5. Derived the backup DES key by XORing the eight base-key bytes with the ASCII
   bytes of the product ID formatted as eight lowercase hexadecimal digits.
   The resulting key and file hashes are kept in the private
   [decryption details](private/tp-link-xx530v/decryption-details.json).
6. Decrypted the backup with **DES-ECB**. Verified its leading 16-byte MD5
   digest against the compressed payload, excluding **three trailing padding
   bytes**. Used the decoder's `uncompress` function with little-endian size
   interpretation. Recovery produced **141139 bytes** before adding a final
   newline, excluding the trailing NUL terminator.
7. Preserved the recovered TP-Link XML-like text as `recovered.xml`. It uses
   unquoted and empty attribute values, so it is not strict XML. Created
   `recovered.normalized.xml` with quoted/escaped attributes for analysis;
   Python's XML parser successfully parsed **2992 elements**. This normalized
   copy is an analysis artifact, not a restore file.
8. Saved the account findings privately, installed Paramiko locally, and
   performed the successful authentication check described above. Rechecked
   that Git ignores the output files.

### Local artifacts

All paths in this table are relative to `devices/private/tp-link-xx530v/`.

| Artifact | Purpose |
| --- | --- |
| `*_backupcfg.bin` | Original encrypted backup, left unchanged |
| `tpconf_bin_xml.py` | Downloaded upstream decoder |
| `recovered.xml` | Recovered configuration in TP-Link's original syntax |
| `recovered.normalized.xml` | Parsed analysis copy with XML attribute quoting |
| `ssh-findings.private.md` | Recovered account passwords and live login result |
| `decryption-details.json` | Derived key, product ID, SHA-256 hashes and verification results |
| `firmware-inspect/` | Selected files extracted from the saved firmware |
| `default_config.decrypted.bin`, `reduced_data_model.decrypted.bin` | Decrypted firmware configuration/model data |

The local `python-deps/` and `uv-cache/` were deleted on 2026-10-29. To rerun
the decoder, use `uv run --no-project --with pycryptodomex python tpconf_bin_xml.py`.

The firmware model defines SSH and Telnet enable/port controls. Its model
defaults are SSH local/remote disabled on port 22, and Telnet local enabled
on port 23 with remote access disabled. These are **firmware model defaults**,
not verified runtime settings; SSH was demonstrably accepting authentication.
The backup also records `EnableCWMP=0`, but current TR-069 state was not checked.
No full network/security configuration audit was performed.

## XPON registration

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
[LAN client log](private/tp-link-xx530v/lan-clients-2026-10-25.md).

| IP | Device | MAC (masked) | Reservation | IP & MAC binding |
| --- | --- | --- | --- | --- |
| .10 | TITAN desktop | `04:7C:16:…:9A` (MSI) | yes | yes |
| .35 | LG-Nunu | `B4:B2:91:…:54` (LG) | yes | yes |
| .50, .51 | Tapo P110 smart plugs | `5C:E9:31:…:7D`, `20:23:51:…:5B` (TP-Link) | yes | yes |
| .100 | TP-Link-Hall access point | `1C:3B:F3:…:FC` (TP-Link) | yes | yes |
| .101 | rigwarl: ER605 v2 (OpenWrt 25.12): switch, Tailscale subnet router and exit node, LAN DNS with ad blocking; static on the device, DHCP/RA off. See [er605-openwrt](../er605-openwrt/README.md) | `24:2F:D0:…:B9` (TP-Link) | no | no |
| .150 | Aruna-206: D-Link downstream router (grandmother's house) | `70:62:B8:…:4A` (D-Link) | yes | yes |

Ranges: `.2–.49` PCs, phones, Apple devices and TV; `.50–.99` IoT; `.100–.150`
network equipment; `.151–.249` dynamic.

**IP & MAC Binding** (Advanced → Security) is enabled. It pins the router's
ARP entries against spoofing. The firmware rejects a DHCP reservation whose MAC
is bound to a different IP (error 5047), so the two lists must agree. Editing a
binding in place fails with error 5401 and can leave a duplicate entry. Delete
the old binding and add a new one instead.

Only globally unique (vendor) MACs are pinned. Devices using locally
administered (randomized) MACs (second hex digit 2, 6, A or E), such as santa,
the Mac and the Android phone, were deliberately unpinned because their MAC can
change and silently orphan the entry. They take pool addresses (or keep an
address set on the device). To pin one, switch it to its hardware MAC for this
network first, then add both a reservation and a binding.

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

## Restore checklist

1. Log in, set **XPON Registration** to the Nokia ONT's GPON SN and Mode X;
   save.
2. Create the VLAN 100 PPPoE connection with the credentials from the Airtel
   Thanks app; enable IPv6 with DHCPv6.
3. Create the VLAN 660 static VoIP connection (priority 4) with the address,
   gateway and DNS above.
4. Add the `10.5.0.0/16` static route via `10.54.208.1`.

Alternatively, restore a config backup under **Advanced → System Tools →
Backup & Restore**, on the same firmware version it was taken from. Never commit
a backup or recovered configuration: this backup's encryption key was derived
from the firmware, and the decrypted contents include plaintext credentials.
