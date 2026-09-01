#!/usr/bin/env bash
# power.sh — Hyprland 电源菜单（不依赖 i3）
# 选中后执行对应动作。
set -uo pipefail

choice="$(echo -e "logout\nreboot\nshutdown" | wofi --dmenu -p "power" 2>/dev/null)"
case "$choice" in
  logout)   hyprctl dispatch exit ;;
  reboot)   systemctl reboot ;;
  shutdown) systemctl poweroff ;;
esac
