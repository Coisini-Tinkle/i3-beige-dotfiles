#!/usr/bin/env bash
set -euo pipefail

readonly CONF_DIR="$HOME/.config/picom"
readonly FULL_CONF="$CONF_DIR/picom-full.conf"
readonly LITE_CONF="$CONF_DIR/picom-lite.conf"
readonly POWER_PATH="/sys/class/power_supply/ADP1/online"
readonly LOG_FILE="/tmp/picom.log"

if [[ -f "$POWER_PATH" ]] && [[ "$(<"$POWER_PATH")" == "1" ]]; then
  config="$FULL_CONF"
else
  config="$LITE_CONF"
fi

exec picom --config "$config" --log-file "$LOG_FILE"
