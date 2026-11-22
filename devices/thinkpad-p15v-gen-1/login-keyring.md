# Autologin and keyring unlock

`/etc/gdm/custom.conf`, `[daemon]` section:

```ini
AutomaticLoginEnable=True
AutomaticLogin=heaton
```

Autologin skips the password prompt, so `pam_oo7` never sees a password and the
keyring would stay locked. This Fedora install uses **oo7-daemon** as the Secret
Service (not gnome-keyring). oo7 can instead read a systemd credential named
`oo7.keyring-encryption-password`; `oo7-daemon.service` already declares
`ImportCredential=oo7.keyring-encryption-password`. Needs systemd 258 or newer
(262 installed) and a TPM2 (present).

The credential is a TPM-sealed blob at
`~/.config/credstore.encrypted/oo7.keyring-encryption-password` (mode 600, directory
mode 700). It is not tracked in this repo and must never be committed.

**Keep the keyring password separate from the login password.** `systemd-creds
encrypt --user` blobs decrypt for any process running as the same user, without a
prompt or polkit. Verified here with a throwaway blob. Sealing the login password
would let any `heaton` process read the `sudo`/SSH password. A keyring-only password
exposes only what an unlocked keyring already exposes over D-Bus.

Set the keyring password: Seahorse (Passwords and Keys) → right-click **Login** →
**Change Password**. oo7's dialog needs the keyring already unlocked and asks only for
the new password. If Login shows a padlock, unlock it first.

Seal it (run in an interactive terminal; the password is typed at the prompt, not
stored in shell history):

```sh
mkdir -p -m 700 ~/.config/credstore.encrypted
systemd-ask-password -n | systemd-creds encrypt --user \
  --name=oo7.keyring-encryption-password - \
  ~/.config/credstore.encrypted/oo7.keyring-encryption-password
chmod 600 ~/.config/credstore.encrypted/oo7.keyring-encryption-password
```

Consequences:

- Changing the **login** password with `passwd` no longer affects the keyring.
- Changing the **keyring** password in Seahorse makes the credential stale. Re-run the
  seal command with the new password, or the keyring locks again at boot.
- While the credential file exists, the daemon unlocks the keyring at service start
  whatever the login method, so a manual login also comes up unlocked. A manual login
  therefore cannot prove the keyring password differs from the login password. Without
  the credential, only a matching password sent by `pam_oo7` unlocks it.
- If unsure the passwords are separate, change the keyring password in Seahorse to a
  newly chosen keyring-only password and re-seal it. That is the only reliable fix.
- Status 2026-11-22: the owner reports the keyring password was changed in Seahorse to
  one that differs from the login password, then sealed. This is owner-reported, not
  machine-verified.
- `/home` is plain btrfs, not LUKS, and autologin is on. Anyone who can boot the
  laptop gets an unlocked session, and root plus this TPM can decrypt the credential.

Check after a reboot (`(false,)` means unlocked):

```sh
gdbus call --session --dest org.freedesktop.secrets \
  --object-path /org/freedesktop/secrets/collection/login \
  --method org.freedesktop.DBus.Properties.Get \
  org.freedesktop.Secret.Collection Locked
journalctl --user -b -u oo7-daemon | grep -i unlocked
```

Verified 2026-11-22: after `systemctl --user restart oo7-daemon` and after a reboot
with autologin, the log shows `Unlocked keyring 'login'` and `Locked` is `(false,)`.
