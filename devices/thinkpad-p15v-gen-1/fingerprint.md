# Fingerprint: login screen yes, sudo no

authselect profile `local` has `with-fingerprint`, which puts `pam_fprintd` first in
`system-auth`. `/etc/pam.d/sudo` included `system-auth`, so every `sudo` asked for a
fingerprint first, including over SSH. `password-auth` has no `pam_fprintd`. The
`auth` line of `/etc/pam.d/sudo` now points at it:

```pam
auth       include      password-auth
```

`/etc/pam.d/sudo-i` includes `sudo`, so it is covered too. GDM's greeter and the lock
screen use `gdm-fingerprint` → `fingerprint-auth`, which is untouched. `pkexec` and
graphical admin prompts use `polkit-1` → `system-auth` and still ask for a
fingerprint. A package update that ships a new `/etc/pam.d/sudo` leaves
`sudo.rpmnew` next to it. Re-apply the line if that file appears. When editing PAM,
keep a `sudo -s` root shell open until `sudo -k; sudo true` works.

One enrolled finger: `right-middle-finger` (`fprintd-list heaton`).
