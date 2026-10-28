#!/bin/sh
# Adds the rigwarl services on top of rigwarl-clean.sh: ad blocking and local
# names (adblock-fast + dnsmasq), the homewatch device watchdog and the manual
# Wi-Fi test server, with LuCI buttons for both.
# Copy homewatch/ to /etc/homewatch/ first, then run on the router:
#   sh rigwarl-services.sh

apk update
apk add adblock-fast luci-app-adblock-fast iperf3 luci-app-commands
chmod 755 /etc/homewatch/homewatch.sh /etc/homewatch/wifitest.sh

# homewatch: the ntfy topic is generated once and kept across upgrades.
# To sign alerts with an ntfy access token, add
#   NTFY_AUTH="<base64url of 'Bearer tk_...' without padding>"
if [ ! -f /etc/homewatch/homewatch.conf ]; then
	topic="rigwarl-$(head -c 9 /dev/urandom | hexdump -v -e '/1 "%02x"')"
	printf 'NTFY_URL="https://ntfy.sh/%s"\nINTERVAL_MIN=10\nFAILS_BEFORE_DOWN=1\n' "$topic" > /etc/homewatch/homewatch.conf
fi
chmod 600 /etc/homewatch/homewatch.conf
grep -q '^/etc/homewatch/' /etc/sysupgrade.conf || echo '/etc/homewatch/' >> /etc/sysupgrade.conf
grep -q homewatch /etc/crontabs/root || echo '*/10 * * * * /etc/homewatch/homewatch.sh' >> /etc/crontabs/root
grep -q homewatch /etc/rc.local || sed -i 's#^exit 0#(sleep 120; /etc/homewatch/homewatch.sh boot) \&\nexit 0#' /etc/rc.local

# LuCI buttons (System > Custom Commands)
while uci -q delete luci.@command[0]; do :; done
for c in "Wi-Fi test server: start (30 min)|/etc/homewatch/wifitest.sh start" \
         "Wi-Fi test server: stop|/etc/homewatch/wifitest.sh stop" \
         "Device watchdog: status|/etc/homewatch/homewatch.sh status"; do
	uci add luci command >/dev/null
	uci set luci.@command[-1].name="${c%%|*}"
	uci set luci.@command[-1].command="${c#*|}"
done
uci commit luci

# DNS: answer LAN and Tailscale clients, resolve upstream directly via Cloudflare
uci set dhcp.@dnsmasq[0].localservice='0'
uci set dhcp.@dnsmasq[0].noresolv='1'
uci -q delete dhcp.@dnsmasq[0].server
for s in 1.1.1.1 1.0.0.1 2606:4700:4700::1111 2606:4700:4700::1001; do
	uci add_list dhcp.@dnsmasq[0].server="$s"
done
while uci -q delete dhcp.@domain[0]; do :; done
for h in xx530v=10.10.1.1 router=10.10.1.1 titan=10.10.1.10 santa=10.10.1.20 lanaya=10.10.1.30 \
         lg-nunu=10.10.1.35 tv=10.10.1.35 tapo-plug-1=10.10.1.50 tapo-plug-2=10.10.1.51 \
         hall-ap=10.10.1.100 archer-c6=10.10.1.100 rigwarl=10.10.1.101 aruna-206=10.10.1.150; do
	uci add dhcp domain >/dev/null
	uci set dhcp.@domain[-1].name="${h%%=*}"
	uci set dhcp.@domain[-1].ip="${h#*=}"
done
uci commit dhcp

# Ad blocking: Hagezi Multi Normal only, plus the Firefox DoH canary
i=0; while uci -q get adblock-fast.@file_url[$i] >/dev/null; do uci set adblock-fast.@file_url[$i].enabled='0'; i=$((i+1)); done
uci add adblock-fast file_url >/dev/null
uci set adblock-fast.@file_url[-1].name='Hagezi - Multi Normal'
uci set adblock-fast.@file_url[-1].url='https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/wildcard/multi-onlydomains.txt'
uci set adblock-fast.@file_url[-1].action='block'
uci set adblock-fast.@file_url[-1].enabled='1'
uci set adblock-fast.config.canary_domains_mozilla='1'
uci set adblock-fast.config.enabled='1'
uci commit adblock-fast

/etc/init.d/dnsmasq restart
/etc/init.d/adblock-fast enable
/etc/init.d/adblock-fast start
/etc/init.d/cron restart
/etc/init.d/rpcd restart
echo "Subscribe to the watchdog alerts at: $(sed -n 's/^NTFY_URL="\(.*\)"/\1/p' /etc/homewatch/homewatch.conf)"
