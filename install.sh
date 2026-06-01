#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
backup_root="$config_home/i3-beige-dotfiles-backup-$(date +%Y%m%d-%H%M%S)"

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

require_cmd rsync

apps=(
  i3
  polybar
  rofi
  picom
  dunst
  kitty
  gtk-3.0
)

mkdir -p "$config_home"

for app in "${apps[@]}"; do
  src="$repo_dir/config/$app"
  dst="$config_home/$app"
  [[ -d "$src" ]] || continue

  if [[ -e "$dst" || -L "$dst" ]]; then
    mkdir -p "$backup_root"
    rsync -a "$dst/" "$backup_root/$app/"
  fi

  mkdir -p "$dst"
  rsync -a "$src/" "$dst/"
done

if [[ ! -f "$config_home/i3/workspace-output-routing.conf" ]]; then
  cp "$config_home/i3/workspace-output-routing.conf.example" \
    "$config_home/i3/workspace-output-routing.conf"
fi

if [[ ! -f "$config_home/i3/display-layouts.conf" ]]; then
  cp "$config_home/i3/display-layouts.conf.example" \
    "$config_home/i3/display-layouts.conf"
fi

if [[ ! -e "$config_home/kitty/current-bg" && -f "$config_home/kitty/img/wallpaper.png" ]]; then
  ln -s "$config_home/kitty/img/wallpaper.png" "$config_home/kitty/current-bg"
fi

find "$config_home/i3" "$config_home/polybar" "$config_home/kitty" \
  -type f -name '*.sh' -exec chmod +x {} +

echo "Installed configs into $config_home"
if [[ -d "$backup_root" ]]; then
  echo "Previous configs were backed up to $backup_root"
fi
echo "Reload i3 manually with Mod+Shift+c, or restart your i3 session."
