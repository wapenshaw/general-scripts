# Local backup recovery — 2026-10-25

All backup processing took place on this PC under `devices/private/tp-link-xx530v/`.
The backup and recovered configuration were not uploaded. Network access was
used to read public tool documentation, download the decoder and Python
dependencies, and perform the local router authentication check.

## Method and validation

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
   [decryption details](../private/tp-link-xx530v/decryption-details.json).
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

## Local artifacts

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

