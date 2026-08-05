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

require_cmd rsync  # for backup only

apps=(
  i3
  polybar
  rofi
  picom
  dunst
  kitty
  gtk-3.0
  systemd/user
)

mkdir -p "$config_home"

for app in "${apps[@]}"; do
  src="$repo_dir/config/$app"
  dst="$config_home/$app"
  [[ -d "$src" ]] || continue

  # If already symlinked to the right place, skip
  if [[ -L "$dst" && "$(readlink -f "$dst")" == "$(readlink -f "$src")" ]]; then
    echo "[skip] $dst already points to repo"
    continue
  fi

  # Backup existing config if it's a real directory (not a symlink)
  if [[ -d "$dst" && ! -L "$dst" ]]; then
    echo "[backup] $dst → $backup_root/$app/"
    mkdir -p "$backup_root"
    rsync -a "$dst/" "$backup_root/$app/" 2>/dev/null || true
    rm -rf "$dst"
  elif [[ -e "$dst" || -L "$dst" ]]; then
    # Stale symlink or plain file — just remove
    rm -rf "$dst"
  fi

  # Create parent dir if needed (e.g. systemd/user → ~/.config/systemd/user)
  mkdir -p "$(dirname "$dst")"
  ln -sfn "$src" "$dst"
  echo "[ok] $dst → $src"
done

# --- Personal scripts in repo/bin → ~/.local/bin (e.g. freeze / reboot-safe) ---
bin_src="$repo_dir/bin"
bin_dst="$HOME/.local/bin"
if [[ -d "$bin_src" ]]; then
  mkdir -p "$bin_dst"
  for f in "$bin_src"/*; do
    [[ -f "$f" ]] || continue
    ln -sfn "$f" "$bin_dst/$(basename "$f")"
    chmod +x "$bin_dst/$(basename "$f")"
    echo "[ok] $bin_dst/$(basename "$f") → $f"
  done
fi

# Make scripts executable (operates on repo files directly)
find "$repo_dir/config/i3" "$repo_dir/config/polybar" "$repo_dir/config/kitty" \
  "$repo_dir/config/picom" \
  -type f -name '*.sh' -exec chmod +x {} + 2>/dev/null || true

# --- Restore gitignored local configs from backup (if available) ---
# These files contain per-machine state (display routing, etc.) and are not in git.
restore_from_backup() {
  local rel="$1"  # e.g. "i3/workspace-output-routing.conf"
  local fallback_example="$2"  # optional example file in repo, used if backup has nothing
  local dst="$repo_dir/config/$rel"

  if [[ -f "$dst" ]]; then
    # Already exists in repo (possibly restored from backup already) — keep it
    return 0
  fi

  if [[ -d "$backup_root" && -f "$backup_root/$rel" ]]; then
    cp "$backup_root/$rel" "$dst"
    echo "[restore] $rel (from backup)"
  elif [[ -n "${fallback_example:-}" && -f "$repo_dir/config/$fallback_example" ]]; then
    cp "$repo_dir/config/$fallback_example" "$dst"
    echo "[init] $rel (from example — edit to match your setup)"
  fi
}

restore_from_backup "i3/display/routing.conf" "i3/display/routing.conf.example"
restore_from_backup "i3/display/layout.conf"  "i3/display/layout.conf.example"

# kitty wallpaper symlink
if [[ ! -e "$repo_dir/config/kitty/current-bg" && -f "$repo_dir/config/kitty/img/wallpaper.png" ]]; then
  ln -sfn "$repo_dir/config/kitty/img/wallpaper.png" "$repo_dir/config/kitty/current-bg"
fi

if command -v systemctl >/dev/null 2>&1; then
  systemctl --user daemon-reload >/dev/null 2>&1 || true
fi

echo ""
echo "Done — all configs symlinked from ~/.config/ to the repo."
echo ""
echo "Edit files anywhere, they're the same file. Git tracks everything in:"
echo "  $repo_dir/config/"
if [[ -d "$backup_root" ]]; then
  echo ""
  echo "Previous configs backed up to: $backup_root"
fi
echo ""
echo "Reload i3: Mod+Shift+r (full restart) or Mod+Shift+c (config reload)"
