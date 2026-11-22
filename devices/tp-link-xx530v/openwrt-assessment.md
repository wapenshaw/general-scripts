# OpenWrt assessment — 2026-10-25

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

## Hardware evidence and unresolved compatibility

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

## Next steps if pursuing the hardware experiment

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

