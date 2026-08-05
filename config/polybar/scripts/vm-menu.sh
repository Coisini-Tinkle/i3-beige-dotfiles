#!/usr/bin/env bash
# vm-menu.sh — 右键 vm-status 图标弹出的 VM 操作菜单
set -euo pipefail

VM="win11"
URI="qemu:///system"

state="$(virsh --connect "$URI" domstate "$VM" 2>/dev/null || echo "unknown")"

case "$state" in
  running)
    entries=" 暂停 (Suspend)\n 关机 (Shutdown)\n 强制关机 (Force Off)\n 打开视图 (virt-viewer)\n 刷新"
    ;;
  paused)
    entries=" 恢复 (Resume)\n 关机 (Shutdown)\n 强制关机 (Force Off)\n 打开视图 (virt-viewer)\n 刷新"
    ;;
  *)
    entries=" 开机 (Start)\n 打开视图 (virt-viewer)\n 刷新"
    ;;
esac

selected="$(echo -e "$entries" | rofi -dmenu -i -p "win11 — $state" \
  -theme-str 'listview { lines: 8; }' 2>/dev/null)"

[[ -z "$selected" ]] && exit 0

case "$selected" in
  *强制关机*) virsh --connect "$URI" destroy "$VM" ;;
  *开机*)     virsh --connect "$URI" start "$VM" ;;
  *暂停*)     virsh --connect "$URI" suspend "$VM" ;;
  *恢复*)     virsh --connect "$URI" resume "$VM" ;;
  *关机*)     virsh --connect "$URI" shutdown "$VM" ;;
  *打开视图*) nohup virt-viewer --connect "$URI" "$VM" >/dev/null 2>&1 & ;;
  *刷新*)     exec "$0" ;;
esac
