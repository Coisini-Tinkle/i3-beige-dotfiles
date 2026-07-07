#!/usr/bin/env bash

set -euo pipefail

exec 8>/tmp/polybar-launch.lock
if command -v flock >/dev/null 2>&1; then
  flock -s 8
fi

pkill -x nm-applet 2>/dev/null || true
pkill -x pasystray 2>/dev/null || true
pkill -x blueman-applet 2>/dev/null || true
pkill -x cc-switch 2>/dev/null || true
pgrep -f '^/usr/bin/python3 /usr/bin/ulauncher --hide-window' | xargs -r kill 2>/dev/null || true

for _ in 1 2 3 4 5 6 7 8 9 10; do
  pgrep -x polybar >/dev/null 2>&1 && break
  sleep 0.2
done

sleep 0.5
command -v cc-switch >/dev/null 2>&1 && /usr/bin/cc-switch >/tmp/cc-switch.log 2>&1 &
sleep 0.4
command -v ulauncher >/dev/null 2>&1 && env GDK_BACKEND=x11 /usr/bin/ulauncher --hide-window --hide-window >/tmp/ulauncher.log 2>&1 &
sleep 0.4
command -v nm-applet >/dev/null 2>&1 && /usr/bin/dbus-launch nm-applet --sm-disable >/tmp/nm-applet.log 2>&1 &
sleep 0.4
command -v pasystray >/dev/null 2>&1 && pasystray >/tmp/pasystray.log 2>&1 &
sleep 0.4
command -v blueman-applet >/dev/null 2>&1 && blueman-applet >/tmp/blueman-applet.log 2>&1 &
