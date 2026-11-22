# Root — assessed 2026-10-29: not possible

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
