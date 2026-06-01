#!/usr/bin/env bash
set -euo pipefail

readonly CONF_DIR="$HOME/.config/picom"
readonly FULL_CONF="$CONF_DIR/picom-full.conf"
readonly LITE_CONF="$CONF_DIR/picom-lite.conf"
POWER_PATH="${PICOM_POWER_PATH:-}"
exec 9>/tmp/picom-launcher.lock
if command -v flock >/dev/null 2>&1; then
  flock -n 9 || exit 0
fi

if [[ -z "$POWER_PATH" ]]; then
  for candidate in /sys/class/power_supply/*/online; do
    [[ -f "$candidate" ]] || continue
    POWER_PATH="$candidate"
    break
  done
fi

is_on_ac() {
  [[ -z "$POWER_PATH" ]] && return 0
  [[ -f "$POWER_PATH" ]] && [[ "$(cat "$POWER_PATH")" == "1" ]]
}

pick_config() {
  if is_on_ac; then echo "$FULL_CONF"; else echo "$LITE_CONF"; fi
}

restart_picom() {
  local config="$1"
  pkill -x picom 2>/dev/null || true
  sleep 0.3
  if command -v picom >/dev/null 2>&1; then
    picom --config "$config" -b 2>&1 9>&- || true
  fi
}

current_config="$(pick_config)"
restart_picom "$current_config"

# event-driven: block on udevadm, wake only on power_supply events
udevadm monitor --property --subsystem-match=power_supply 2>/dev/null \
  | grep --line-buffered "POWER_SUPPLY_ONLINE" \
  | while IFS= read -r _; do
      sleep 0.3
      new_config="$(pick_config)"
      if [[ "$new_config" != "$current_config" ]]; then
        current_config="$new_config"
        restart_picom "$current_config"
      fi
    done
