#!/usr/bin/env bash

set -euo pipefail

readonly SOURCE_IMAGE="/home/coisini/.config/i3/themes/current/wallpaper.png"
readonly OUTPUT_IMAGE="/tmp/i3-lockscreen.png"
BACKGROUND_COLOR="#f5ebe1"
LOCK_RADIUS="${I3LOCK_RADIUS:-120}"
LOCK_RING_WIDTH="${I3LOCK_RING_WIDTH:-16}"

if [[ -f "/home/coisini/.config/i3/themes/current/theme.conf" ]]; then
  # shellcheck source=/dev/null
  source "/home/coisini/.config/i3/themes/current/theme.conf"
  BACKGROUND_COLOR="${LOCK_BG:-${PANEL:-$BACKGROUND_COLOR}}"
fi

# 逐屏 cover 合成虚拟画布（避免锁屏壁纸卡在两屏中间），底色用主题 LOCK_BG
WALLPAPER_BG="$BACKGROUND_COLOR" \
  bash "/home/coisini/.config/i3/set-wallpaper.sh" "$SOURCE_IMAGE" "$OUTPUT_IMAGE"

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
