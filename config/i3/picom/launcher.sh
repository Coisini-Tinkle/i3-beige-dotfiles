#!/usr/bin/env bash
set -euo pipefail

readonly PICOM_BIN="$HOME/.local/bin/picom-ft"
readonly CONF_DIR="$HOME/.config/picom"
readonly FULL_CONF="$CONF_DIR/picom-anim.conf"
readonly LITE_CONF="$CONF_DIR/picom-anim-lite.conf"
readonly POWER_PATH="/sys/class/power_supply/ADP1/online"
readonly LOG_FILE="/tmp/picom.log"

# Fall back to system picom if picom-ft not installed
if [[ ! -x "$PICOM_BIN" ]]; then
  exec picom --config "$CONF_DIR/picom-full.conf" --log-file "$LOG_FILE"
fi

if [[ -f "$POWER_PATH" ]] && [[ "$(<"$POWER_PATH")" == "1" ]]; then
  config="$FULL_CONF"
else
  config="$LITE_CONF"
fi

exec "$PICOM_BIN" --config "$config" --log-file "$LOG_FILE"
