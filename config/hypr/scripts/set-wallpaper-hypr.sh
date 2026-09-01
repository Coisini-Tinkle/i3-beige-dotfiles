#!/usr/bin/env bash
# set-wallpaper-hypr.sh [<image>]
#
# Hyprland 版壁纸设置：用 swww 对每块屏独立 cover 填充。
# 等价于 i3 那套「feh 合成虚拟画布再铺设」，但 Wayland 下 swww 每块屏
# 各自 cover，无需 xrandr 几何合成，天然适配多屏。
#
# 默认图复用 i3 的 beige 壁纸（只读引用，不改 i3 文件）。
set -uo pipefail

DEFAULT_IMG="$HOME/.config/i3/themes/current/wallpaper.png"
IMG="${1:-$DEFAULT_IMG}"

[[ -f "$IMG" ]] || { echo "set-wallpaper-hypr: 需要图片文件: $IMG" >&2; exit 1; }
command -v swww >/dev/null 2>&1 || { echo "set-wallpaper-hypr: 未找到 swww" >&2; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "set-wallpaper-hypr: 未找到 jq" >&2; exit 1; }

# 确保 swww 守护进程已起
swww query >/dev/null 2>&1 || swww init >/dev/null 2>&1 || true

# exec-once 阶段 Hyprland 的 IPC socket 可能还没起来，等它就绪再枚举显示器。
for i in $(seq 1 20); do
  hyprctl monitors -j >/dev/null 2>&1 && break
  sleep 0.3
done

# 对每块屏独立 cover（swww 单屏模式默认就是 cover 填充该屏）
for out in $(hyprctl monitors -j 2>/dev/null | jq -r '.[].name'); do
  [[ -n "$out" ]] || continue
  swww img --output "$out" "$IMG" \
    --transition-type none 2>/dev/null || true
done
