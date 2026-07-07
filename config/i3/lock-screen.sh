#!/usr/bin/env bash

set -euo pipefail

readonly SOURCE_IMAGE="$HOME/.config/i3/themes/beige/wallpaper.png"
readonly OUTPUT_IMAGE="/tmp/i3-lockscreen.png"
readonly BACKGROUND_COLOR="#f5ebe1"
readonly LOCK_RADIUS="${I3LOCK_RADIUS:-1440}"
readonly LOCK_RING_WIDTH="${I3LOCK_RING_WIDTH:-128}"

screen_size="$(
  xrandr --query \
    | awk '/^Screen 0:/ { for (i = 1; i <= NF; ++i) if ($i == "current") { print $(i+1) "x" $(i+3); exit } }' \
    | tr -d ','
)"

if [[ -z "$screen_size" ]]; then
  screen_size="1920x1080"
fi

convert "$SOURCE_IMAGE" \
  -resize "${screen_size}" \
  -background "$BACKGROUND_COLOR" \
  -gravity center \
  -extent "${screen_size}" \
  "$OUTPUT_IMAGE"

lock_cmd="${I3LOCK_BIN:-}"
if [[ -z "$lock_cmd" && -x "$HOME/.local/bin/i3lock-color" ]]; then
  lock_cmd="$HOME/.local/bin/i3lock-color"
elif [[ -z "$lock_cmd" ]]; then
  lock_cmd="i3lock"
fi

if [[ "$lock_cmd" == *i3lock-color ]]; then
  exec "$lock_cmd" \
    -i "$OUTPUT_IMAGE" \
    --radius "$LOCK_RADIUS" \
    --ring-width "$LOCK_RING_WIDTH" \
    "$@"
fi

exec "$lock_cmd" -i "$OUTPUT_IMAGE" "$@"
