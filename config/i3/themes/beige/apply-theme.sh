#!/usr/bin/env bash
set -euo pipefail
THEME_DIR="$HOME/.config/i3/themes/beige"

# 幂等备份：仅当目标存在且尚无 .bak 时备份
backup_once() {
  local f="$1"
  if [ -e "$f" ] && [ ! -e "$f.bak" ]; then
    cp -a "$f" "$f.bak"
    echo "backed up: $f -> $f.bak"
  fi
}

restore() {
  local f="$1"
  if [ -e "$f.bak" ]; then
    cp -a "$f.bak" "$f"
    echo "restored: $f.bak -> $f"
  fi
}

deploy() {
  echo "== deploying beige theme =="
  # i3 config / lock-screen 已直接改在 live 文件（含 .bak），此处确保壁纸与各组件 include 就位
  backup_once "$HOME/.config/kitty/kitty.conf"
  grep -q "themes/beige/kitty-beige.conf" "$HOME/.config/kitty/kitty.conf" \
    || echo "include ~/.config/i3/themes/beige/kitty-beige.conf" >> "$HOME/.config/kitty/kitty.conf"
  # btop/cava/fastfetch
  for d in btop cava fastfetch; do
    mkdir -p "$HOME/.config/$d"
    cp -r "$THEME_DIR/src-ref/$d/." "$HOME/.config/$d/" 2>/dev/null || true
  done
  echo "deploy done"
}

reload_all() {
  command -v feh >/dev/null && feh --no-fehbg --bg-fill "$THEME_DIR/wallpaper.png" || true
  i3-msg reload >/dev/null 2>&1 || true
  bash "$HOME/.config/polybar/launch.sh" || true
  pkill -x dunst 2>/dev/null || true
  dunst -conf "$HOME/.config/dunst/dunstrc" >/dev/null 2>&1 &
  pkill -USR1 kitty 2>/dev/null || true
  echo "== reloaded =="
}

case "${1:-apply}" in
  apply)   deploy; reload_all ;;
  restore) echo "手动还原：对各 *.bak 执行 cp 回去（见 README）"; ;;
  *) echo "usage: apply-theme.sh [apply|restore]"; exit 1 ;;
esac
