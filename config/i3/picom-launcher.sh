#!/usr/bin/env bash
set -euo pipefail

readonly CONF_DIR="$HOME/.config/picom"
readonly FULL_CONF="$CONF_DIR/picom-full.conf"
readonly LITE_CONF="$CONF_DIR/picom-lite.conf"
POWER_PATH="${PICOM_POWER_PATH:-}"
readonly LOG_FILE="/tmp/picom.log"

if [[ -z "$POWER_PATH" ]]; then
  for candidate in /sys/class/power_supply/*/online; do
    [[ -f "$candidate" ]] || continue
    POWER_PATH="$candidate"
    break
  done
fi

config="$FULL_CONF"
if [[ -n "$POWER_PATH" && -f "$POWER_PATH" ]] && [[ "$(<"$POWER_PATH")" != "1" ]]; then
  config="$LITE_CONF"
fi

exec picom --config "$config" --log-file "$LOG_FILE"
