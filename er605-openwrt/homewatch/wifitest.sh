#!/bin/sh
# Manual Wi-Fi speed test server: "start" runs an iperf3 server on port 5201
# for 30 minutes (then it stops by itself), "stop" ends it early.
PID=/var/run/wifitest-iperf3.pid
TIMER=/var/run/wifitest-timer.pid
case "$1" in
start)
	pidof iperf3 >/dev/null && { echo "iperf3 server already running on rigwarl (10.10.1.101:5201)"; exit 0; }
	iperf3 -s -D -I "$PID"
	start-stop-daemon -S -b -m -p "$TIMER" -x /bin/sh -- -c "sleep 1800; kill \$(cat $PID) 2>/dev/null"
	sleep 1
	pidof iperf3 >/dev/null && echo "iperf3 server running on 10.10.1.101:5201 for 30 minutes" || echo "failed to start iperf3"
	;;
stop)
	start-stop-daemon -K -q -p "$TIMER" 2>/dev/null
	killall iperf3 2>/dev/null && echo "iperf3 server stopped" || echo "iperf3 server was not running"
	;;
*)
	pidof iperf3 >/dev/null && echo "running" || echo "stopped"
	;;
esac
