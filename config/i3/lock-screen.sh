#!/usr/bin/env bash

set -euo pipefail

readonly SOURCE_IMAGE="$HOME/.config/i3/themes/beige/wallpaper.png"
readonly OUTPUT_IMAGE="/tmp/i3-lockscreen.png"
readonly BACKGROUND_COLOR="#f5ebe1"

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

exec i3lock -i "$OUTPUT_IMAGE" "$@"
