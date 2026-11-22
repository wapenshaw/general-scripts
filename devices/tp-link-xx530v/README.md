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
| Changes to router | LAN/DHCP only (2026-10-25): DHCP pool, reservations and IP & MAC bindings reorganised; see [LAN addressing](network-config.md#lan-addressing--2026-10-25). No key installation, restore, reboot or flashing |

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

## Contents

- [Access restrictions](access-restrictions.md)
- [OpenWrt assessment](openwrt-assessment.md)
- [Backup recovery](backup-recovery.md)
- [Network configuration](network-config.md)
- [Restore checklist](restore-checklist.md)
