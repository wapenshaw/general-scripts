# SSH authentication and session restrictions — 2026-10-25

Password authentication succeeded at **10.10.1.1:22** with username **`user`**
and the password recovered from the backup. The following command reaches the
SSH service, but a usable shell session is **not** available:

```powershell
ssh -o NumberOfPasswordPrompts=1 user@10.10.1.1
```

The password is in the local-only
[SSH findings](../private/tp-link-xx530v/ssh-findings.private.md). This link and
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

## Key-login follow-up — 2026-10-25

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
and ISP setup. The experimental [OpenWrt option](openwrt-assessment.md) has not
been validated on this particular board. No flashing, config restore or device
modification was attempted.

