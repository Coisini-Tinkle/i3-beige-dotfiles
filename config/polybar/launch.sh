#!/usr/bin/env bash

# Use a dedicated lock path. NOTE: never let long-lived children inherit fd 9 —
# a prior version leaked it into tray.sh (via `theme-switcher render-polybar`
# spawned without `9>&-`), which then held the flock forever and made every
# later launch bail ("wedge"). The path below is distinct from any historically
# leaked lock so a stale holder can't block us.
lockfile="/tmp/polybar-launch-mutex.lock"
exec 9>"$lockfile"
if command -v flock >/dev/null 2>&1; then
  # Serialize concurrent triggers (i3 exec_always, hotplug-watch, theme-switch):
  # only one launch.sh may manipulate polybar at a time. Wait a bounded time; if
  # another instance is actively managing it, bail out instead of racing it. A
  # racing pkill used to leave zero bars running. A truly wedged holder is rare;
  # bailing leaves the currently-running bars intact.
  if ! flock -w 15 9; then
    echo "polybar-launch: another instance holds the lock; skipping" >&2
    exit 0
  fi
fi

# Stop a stale i3-workspaces helper so a re-launch doesn't leave one behind.
ps -eo pid,args | awk '/[i]3-workspaces\.sh/ {print $1}' | xargs -r kill 2>/dev/null || true

if ! command -v polybar >/dev/null 2>&1; then
  exit 0
fi

# Determine monitors BEFORE killing anything. If none are active (e.g. a
# transient display flap), leave the existing bars alone instead of killing
# them into a zero-bar gap.
primary="$(xrandr --listactivemonitors | awk 'NR > 1 && $1 ~ /\*/ { print $NF; exit }')"
others=()
if [[ -z "$primary" ]]; then
  mapfile -t all < <(xrandr --listactivemonitors | awk 'NR > 1 { print $NF }')
  primary="${all[0]:-}"
  others=("${all[@]:1}")
elif [[ -n "$primary" ]]; then
  mapfile -t others < <(xrandr --listactivemonitors | awk -v p="$primary" 'NR > 1 && $NF != p { print $NF }')
fi

if [[ -z "$primary" ]]; then
  echo "polybar-launch: no active monitor found; leaving existing bars running" >&2
  exit 0
fi

# Now safe to tear down the old instances.
pkill -x polybar 2>/dev/null || true
for _ in 1 2 3 4 5 6 7 8 9 10; do
  pgrep -x polybar >/dev/null 2>&1 || break
  sleep 0.2
done

if pgrep -x polybar >/dev/null 2>&1; then
  pkill -KILL -x polybar 2>/dev/null || true
  sleep 0.2
fi

# 9>&- is required: without it the theme-switcher (and anything it launches,
# e.g. tray.sh) inherits our lock fd and would hold the flock open forever.
SKIP_LIVE_POLYBAR=0 "$HOME/.config/i3/theme-switcher.sh" render-polybar >/dev/null 2>&1 9>&- || true

MONITOR="$primary" nohup polybar -r main -c "$HOME/.config/polybar/config.ini" >/tmp/polybar-main.log 2>&1 </dev/null 9>&- &

for m in "${others[@]}"; do
  MONITOR="$m" nohup polybar -r secondary -c "$HOME/.config/polybar/config.ini" >/tmp/polybar-secondary-"$m".log 2>&1 </dev/null 9>&- &
done
