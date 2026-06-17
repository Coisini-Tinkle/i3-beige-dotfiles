#!/usr/bin/env bash

exec 9>/tmp/polybar-launch.lock
if command -v flock >/dev/null 2>&1; then
  # -w 5: serialize concurrent launches, but never block forever. If a previous
  # launch.sh wedged while holding the lock (seen 2026-06-17: a hung instance held
  # it 14 min and blocked every restart), give up after 5s and proceed best-effort.
  # The pkill -x polybar below resets state, so double-spawn is not a concern.
  if ! flock -w 5 9; then
    echo "polybar-launch: lock busy >5s, assuming previous launch is stuck; proceeding without lock" >&2
  fi
fi

pkill -x polybar 2>/dev/null || true
ps -eo pid,args | awk '/[i]3-workspaces\.sh/ {print $1}' | xargs -r kill 2>/dev/null || true

if ! command -v polybar >/dev/null 2>&1; then
  exit 0
fi

for _ in 1 2 3 4 5 6 7 8 9 10; do
  pgrep -x polybar >/dev/null 2>&1 || break
  sleep 0.2
done

if pgrep -x polybar >/dev/null 2>&1; then
  pkill -KILL -x polybar 2>/dev/null || true
  sleep 0.2
fi

SKIP_LIVE_POLYBAR=0 "$HOME/.config/i3/theme-switcher.sh" render-polybar >/dev/null 2>&1 || true

primary="$(xrandr --listactivemonitors | awk 'NR > 1 && $2 ~ /\*/ { print $NF; exit }')"
others=()
if [[ -n "$primary" ]]; then
  mapfile -t others < <(xrandr --listactivemonitors | awk -v p="$primary" 'NR > 1 && $NF != p { print $NF }')
fi

if [[ -z "$primary" ]]; then
  mapfile -t all < <(xrandr --listactivemonitors | awk 'NR > 1 { print $NF }')
  primary="${all[0]:-}"
  others=("${all[@]:1}")
fi

if [[ -n "$primary" ]]; then
  MONITOR="$primary" nohup polybar -r main -c "$HOME/.config/polybar/config.ini" >/tmp/polybar-main.log 2>&1 </dev/null 9>&- &
fi

for m in "${others[@]}"; do
  MONITOR="$m" nohup polybar -r secondary -c "$HOME/.config/polybar/config.ini" >/tmp/polybar-secondary-"$m".log 2>&1 </dev/null 9>&- &
done
