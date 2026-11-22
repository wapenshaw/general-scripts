# Restore checklist

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
