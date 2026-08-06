#!/usr/bin/env bash
# picom-menu.sh — right-click menu for picom status icon
set -euo pipefail

state="$(systemctl --user is-active picom.service 2>/dev/null || echo "inactive")"

case "$state" in
  active)
    entries=" 停止 (Stop)\n 重启 (Restart)\n󰒓 查看日志 (View Log)\n 刷新"
    ;;
  *)
    entries=" 启动 (Start)\n󰒓 查看日志 (View Log)\n 刷新"
    ;;
esac

selected="$(echo -e "$entries" | rofi -dmenu -i -p "picom — $state" \
  -me-select-entry '' -me-accept-entry mouseprimary \
  -theme-str 'listview { lines: 8; }' 2>/dev/null)"

[[ -z "$selected" ]] && exit 0

case "$selected" in
  *启动*)
    systemctl --user start picom.service
    ;;
  *停止*)
    systemctl --user stop picom.service
    ;;
  *重启*)
    systemctl --user restart picom.service
    ;;
  *日志*)
    kitty --class kitty-float -e sh -c 'less +G /tmp/picom.log 2>/dev/null; exec $SHELL' &
    ;;
  *刷新*)
    exec "$0"
    ;;
esac
