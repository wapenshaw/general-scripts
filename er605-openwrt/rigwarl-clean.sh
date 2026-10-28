#!/bin/sh
# Reset rigwarl (ER605 v2, OpenWrt 25.12) to stock config plus: 5-port switch at
# 10.10.1.101, SLAAC IPv6, Tailscale subnet router/exit node, IPv6 input lockdown,
# weekly package auto-upgrade. Tailscale state/prefs, root password, SSH host keys,
# hostname and time zone are kept.
exec >/tmp/rigwarl-clean.log 2>&1
set -x

# Leftovers from the old main-router role
apk del https-dns-proxy luci-app-https-dns-proxy
rm -f /etc/config/https-dns-proxy /etc/config/sqm /etc/config/luci-opkg
rm -rf /etc/opkg

# DHCP/DNS: stock, but no DHCP server or RA on the LAN
cp /rom/etc/config/dhcp /etc/config/dhcp
uci -q delete dhcp.wan
uci set dhcp.lan.ignore='1'
uci set dhcp.lan.dhcpv4='disabled'
uci set dhcp.lan.dhcpv6='disabled'
uci set dhcp.lan.ra='disabled'
uci commit dhcp

# Network: every port in one bridge, static IPv4, SLAAC IPv6, Tailscale interface
ula=$(uci -q get network.globals.ula_prefix)
cat > /etc/config/network <<NET
config interface 'loopback'
	option device 'lo'
	option proto 'static'
	option ipaddr '127.0.0.1'
	option netmask '255.0.0.0'

config globals 'globals'
	option ula_prefix '${ula}'

config device
	option name 'br-lan'
	option type 'bridge'
	list ports 'lan2'
	list ports 'lan3'
	list ports 'lan4'
	list ports 'lan5'
	list ports 'wan1'

config interface 'lan'
	option device 'br-lan'
	option proto 'static'
	option ipaddr '10.10.1.101'
	option netmask '255.255.255.0'
	option gateway '10.10.1.1'
	list dns '10.10.1.1'

config interface 'lan6'
	option device 'br-lan'
	option proto 'dhcpv6'
	option reqaddress 'try'
	option reqprefix 'no'

config interface 'tailscale'
	option proto 'unmanaged'
	option device 'tailscale0'
NET

# Firewall: stock, plus the Tailscale zone and IPv6 lockdown of the router itself
cp /rom/etc/config/firewall /etc/config/firewall
uci add_list firewall.@zone[0].network='lan6'
uci add firewall zone
uci set firewall.@zone[-1].name='tailscale'
uci set firewall.@zone[-1].input='ACCEPT'
uci set firewall.@zone[-1].output='ACCEPT'
uci set firewall.@zone[-1].forward='ACCEPT'
uci add_list firewall.@zone[-1].network='tailscale'
uci add firewall forwarding
uci set firewall.@forwarding[-1].src='tailscale'
uci set firewall.@forwarding[-1].dest='lan'
uci add firewall forwarding
uci set firewall.@forwarding[-1].src='lan'
uci set firewall.@forwarding[-1].dest='tailscale'
uci add firewall rule
uci set firewall.@rule[-1].name='Allow-Tailscale-IPv6'
uci set firewall.@rule[-1].src='lan'
uci set firewall.@rule[-1].family='ipv6'
uci set firewall.@rule[-1].proto='udp'
uci set firewall.@rule[-1].dest_port='41641'
uci set firewall.@rule[-1].target='ACCEPT'
uci add firewall rule
uci set firewall.@rule[-1].name='Block-nonlocal-IPv6-to-router'
uci set firewall.@rule[-1].src='lan'
uci set firewall.@rule[-1].family='ipv6'
uci set firewall.@rule[-1].proto='tcp udp'
uci set firewall.@rule[-1].src_ip='!fe80::/10'
uci set firewall.@rule[-1].target='DROP'
uci commit firewall

# Weekly package auto-upgrade (Tailscale and feed updates), Sunday 04:00
cat > /etc/crontabs/root <<CRON
0 4 * * 0 apk update >/tmp/apk-auto-upgrade.log 2>&1 && apk upgrade >>/tmp/apk-auto-upgrade.log 2>&1
CRON
/etc/init.d/cron enable

/etc/init.d/network reload
sleep 8
/etc/init.d/dnsmasq restart
/etc/init.d/odhcpd restart
/etc/init.d/firewall restart
/etc/init.d/cron restart
echo DONE
