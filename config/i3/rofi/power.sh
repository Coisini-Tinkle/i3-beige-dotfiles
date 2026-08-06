#!/usr/bin/env bash
set -euo pipefail

entries="󰌾 Lock\n󰍃 Logout\n󰜉 Reboot\n󰐥 Shutdown"

selected="$(echo -e "$entries" | rofi -dmenu -i -p "Power" \
  -me-select-entry '' -me-accept-entry mouseprimary \
  -theme-str 'listview { lines: 4; }' 2>/dev/null)"

case "$selected" in
  *Lock)    bash ~/.config/i3/lock.sh ;;
  *Logout)  i3-msg exit ;;
  *Reboot)  systemctl reboot ;;
  *Shutdown) systemctl poweroff ;;
esac
