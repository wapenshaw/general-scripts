# Lenovo ThinkPad P15v Gen 1

Last inspected: **2026-10-24**. Times below use **Asia/Kolkata (IST, UTC+05:30)**.

## Device

| Item | Value |
| --- | --- |
| Manufacturer | Lenovo |
| Model | ThinkPad P15v Gen 1 |
| Machine type / model | **20TQ004YMX** (type **20TQ**) |
| Operating system at inspection | Fedora Linux 44 Workstation |
| Integrated graphics | Intel UHD Graphics (Comet Lake) |
| Discrete graphics | NVIDIA Quadro P620 |

## Configuration summary — 2026-11-22

Hostname `santa`, user `heaton`, Fedora Linux 45 Workstation (GNOME, GDM, Wayland).
The machine is used remotely over SSH and GNOME Remote Desktop, so it must come back
from a reboot logged in with the keyring unlocked, and must not sleep on AC. The
battery readings in [battery.md](battery.md) were taken on Fedora 44; nothing here changes them.

| Setting | State |
| --- | --- |
| GDM autologin | **Enabled** for `heaton` |
| Login keyring | **Unlocked at autologin** from a TPM-sealed credential |
| Fingerprint | Login screen, lock screen: **yes**. `sudo`: **no** (password only) |
| Sleep on AC | **Never**: logged in, at the login screen, and on lid close |
| Sleep on battery | Suspend after **15 min** idle; lid close suspends |

## Files

| File | Contents |
| --- | --- |
| [battery.md](battery.md) | Battery replacement identifiers, charging and performance preferences, battery health and discharge snapshots, graphics power observation, recheck commands |
| [login-keyring.md](login-keyring.md) | GDM autologin and unlocking the oo7 keyring from a TPM-sealed credential |
| [fingerprint.md](fingerprint.md) | Fingerprint at the login and lock screens, password for `sudo` |
| [sleep.md](sleep.md) | Sleep policy (AC never, battery 15 min), lid close, why SSH cannot wake the laptop, Wake-on-LAN options |
