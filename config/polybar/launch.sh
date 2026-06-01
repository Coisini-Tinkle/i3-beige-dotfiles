#!/usr/bin/env bash

exec 9>/tmp/polybar-launch.lock
if command -v flock >/dev/null 2>&1; then
  flock -x 9
fi

polybar-msg cmd quit >/dev/null 2>&1 || true
pkill -x polybar 2>/dev/null || true

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
