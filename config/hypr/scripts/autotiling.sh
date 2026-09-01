#!/usr/bin/env bash
# autotiling.sh — Hyprland 自动平铺（对标 i3 的 autotiling）
#
# 优先用 pyautotiling（pip install pyautotiling），缺失则 no-op，不影响启动。
set -uo pipefail

if command -v pyautotiling >/dev/null 2>&1; then
  exec pyautotiling
elif command -v python3 >/dev/null 2>&1 && python3 -c "import autotiling" 2>/dev/null; then
  exec python3 -m autotiling
else
  echo "autotiling: pyautotiling 未安装，跳过（可手动 pip install pyautotiling）" >&2
  exit 0
fi
