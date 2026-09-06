#!/bin/sh
PATH="/usr/sbin:/usr/bin:/sbin:/bin"

SERVICE="/etc/init.d/AdGuardHome"
configpath="$(uci -q get AdGuardHome.AdGuardHome.configpath)"
[ -n "$configpath" ] || configpath="/etc/AdGuardHome.yaml"

fail_count=0
sleep 2

while :; do
	# stop_service creates this marker before touching DNS state.  Exiting here
	# prevents the monitor from re-enabling redirection while procd is stopping.
	[ -e /var/run/AdG_stopping ] && exit 0

	# A missing or empty config is a legitimate first-run state.  Never
	# redirect DNS until AdGuard Home has produced a real configuration.
	if [ ! -s "$configpath" ]; then
		if [ "$(cat /var/run/AdG_redir 2>/dev/null)" = "1" ]; then
			"$SERVICE" do_redirect 0 >/dev/null 2>&1
		fi
		fail_count=0
		sleep 5
		continue
	fi

	if "$SERVICE" running main >/dev/null 2>&1; then
		fail_count=0
		if [ "$(cat /var/run/AdG_redir 2>/dev/null)" != "1" ]; then
			"$SERVICE" do_redirect 1 >/dev/null 2>&1
		fi
		sleep 10
		continue
	fi

	# procd may be in the middle of a respawn cycle.  Give it several
	# opportunities to recover before falling back to the system DNS path.
	fail_count=$((fail_count + 1))
	if [ "$fail_count" -ge 4 ]; then
		logger -t AdGuardHome "main instance unavailable; disabling DNS redirection"
		"$SERVICE" do_redirect 0 >/dev/null 2>&1
		exit 0
	fi

	sleep 10
done
