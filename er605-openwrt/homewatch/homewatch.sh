#!/bin/sh
# homewatch: pings the hosts in /etc/homewatch/hosts (cron, every INTERVAL_MIN) and
# sends an ntfy notification when one goes down or comes back. Messages that
# cannot be sent (internet down) are queued and sent on the next run. NTFY_AUTH
# (optional) is the ntfy auth query value: base64url("Bearer <access token>").
#   homewatch.sh          one check pass (cron)
#   homewatch.sh boot     announce a (re)boot, e.g. after a power cut
#   homewatch.sh status   print the current state of every host
. /etc/homewatch/homewatch.conf
STATE=/tmp/homewatch
QUEUE=$STATE/queue
HISTORY=/etc/homewatch/history.log
INTERVAL_MIN=${INTERVAL_MIN:-1}
mkdir -p "$STATE"
now=$(date +%s)

urlenc() { echo "$1" | sed 's/%/%25/g; s/ /%20/g; s/&/%26/g; s/?/%3F/g; s/#/%23/g'; }

send() { # title message tags
	echo "$(date '+%F %T') $1: $2" >> "$HISTORY"
	tail -n 1000 "$HISTORY" > "$HISTORY.tmp" && mv "$HISTORY.tmp" "$HISTORY"
	printf '%s\t%s\t%s\n' "$1" "$2" "$3" >> "$QUEUE"
}

flush() {
	[ -s "$QUEUE" ] || return 0
	: > "$QUEUE.retry"
	while IFS="$(printf '\t')" read -r title msg tags; do
		uclient-fetch -q -T 10 -O /dev/null --post-data "$msg" \
			"$NTFY_URL?title=$(urlenc "$title")&tags=$tags${NTFY_AUTH:+&auth=$NTFY_AUTH}" 2>/dev/null ||
			printf '%s\t%s\t%s\n' "$title" "$msg" "$tags" >> "$QUEUE.retry"
	done < "$QUEUE"
	mv "$QUEUE.retry" "$QUEUE"
}

ago() { # seconds -> "3h 12m"
	s=$1; h=$((s / 3600)); m=$((s % 3600 / 60))
	[ "$h" -gt 0 ] && echo "${h}h ${m}m" || echo "${m}m"
}

reachable() { # comma-separated targets; any reply counts
	for t in $(echo "$1" | tr ',' ' '); do
		case "$t" in
		arp:*) # device ignores ping (e.g. a router's WAN side): count a fresh ARP reply
			ip neigh flush to "${t#arp:}" >/dev/null 2>&1
			ping -c 1 -W 2 "${t#arp:}" >/dev/null 2>&1
			ip neigh show to "${t#arp:}" | grep -q -E 'REACHABLE|DELAY' && return 0 ;;
		*)
			ping -c 3 -W 2 "$t" >/dev/null 2>&1 && return 0 ;;
		esac
	done
	return 1
}

case "$1" in
status)
	while read -r ip name; do
		case "$ip" in ''|\#*) continue ;; esac
		since=; st=unknown
		[ -f "$STATE/$name" ] && read -r st fails since < "$STATE/$name"
		printf '%-12s %-16s %s%s\n' "$name" "$ip" "$st" "${since:+ for $(ago $((now - since)))}"
	done < /etc/homewatch/hosts
	exit 0 ;;
boot)
	send "rigwarl started" "rigwarl (re)booted; up $(awk '{print int($1/60)}' /proc/uptime) min. A power cut or reboot happened." "electric_plug"
	flush; exit 0 ;;
esac

while read -r ip name; do
	case "$ip" in ''|\#*) continue ;; esac
	f="$STATE/$name"
	st=up; fails=0; since=$now
	[ -f "$f" ] && read -r st fails since < "$f"
	if reachable "$ip"; then
		if [ "$st" = down ]; then
			send "$name is back" "$name ($ip) is back online after $(ago $((now - since)))." "white_check_mark"
			st=up; since=$now
		fi
		fails=0
	else
		fails=$((fails + 1))
		if [ "$st" = up ] && [ "$fails" -ge "$FAILS_BEFORE_DOWN" ]; then
			st=down; since=$((now - fails * INTERVAL_MIN * 60))
			send "$name is down" "$name ($ip) has not answered for $((fails * INTERVAL_MIN)) minutes." "warning"
		fi
	fi
	echo "$st $fails $since" > "$f"
done < /etc/homewatch/hosts
flush
