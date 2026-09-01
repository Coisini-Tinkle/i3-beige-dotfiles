#!/usr/bin/env bash
# set-wallpaper-hypr.sh [<image>]
#
# Hyprland 版壁纸设置：用 swaybg 对每块屏独立 fill 填充。
# 等价于 i3 那套「feh 合成虚拟画布再铺设」，但 Wayland 下 swaybg 每块屏
# 各自 fill，无需 xrandr 几何合成，天然适配多屏。
#
# 阶段优先做静态壁纸（swaybg 仅静态；后续想用动画壁纸可换 swww）。
# 默认图复用 i3 的 beige 壁纸（只读引用，不改 i3 文件）。
set -uo pipefail

DEFAULT_IMG="$HOME/.config/i3/themes/current/wallpaper.png"
IMG="${1:-$DEFAULT_IMG}"

[[ -f "$IMG" ]] || { echo "set-wallpaper-hypr: 需要图片文件: $IMG" >&2; exit 1; }
command -v swaybg >/dev/null 2>&1 || { echo "set-wallpaper-hypr: 未找到 swaybg" >&2; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "set-wallpaper-hypr: 未找到 jq" >&2; exit 1; }

# exec-once 阶段 Hyprland 的 IPC socket 可能还没起来，等它就绪再枚举显示器。
for i in $(seq 1 20); do
  hyprctl monitors -j >/dev/null 2>&1 && break
  sleep 0.3
done

# 先杀掉旧 swaybg 实例，避免重复叠加
pkill -x swaybg >/dev/null 2>&1 || true

# swaybg 支持多组 -o <输出> -i <图> -m <模式> 一次设置所有屏
args=()
for out in $(hyprctl monitors -j 2>/dev/null | jq -r '.[].name'); do
  [[ -n "$out" ]] || continue
  args+=(-o "$out" -i "$IMG" -m fill)
done

[[ ${#args[@]} -gt 0 ]] || { echo "set-wallpaper-hypr: 未枚举到显示器" >&2; exit 1; }
swaybg "${args[@]}" >/dev/null 2>&1 &
