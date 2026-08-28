#!/usr/bin/env bash
set -euo pipefail

layout_script="${HOME}/.config/i3/display/layout.sh"
polybar_launcher="${HOME}/.config/polybar/launch.sh"
interval="${DISPLAY_HOTPLUG_POLL_INTERVAL:-2}"
external_layout="${DISPLAY_HOTPLUG_LAYOUT:-left}"
monitor_layouts_file="${HOME}/.config/i3/display/layout.conf"
once=0

exec 9>/tmp/display-hotplug-watch.lock
if command -v flock >/dev/null 2>&1; then
  flock -n 9 || exit 0
fi

if [[ "${1:-}" == "--once" ]]; then
  once=1
fi

current_externals() {
  xrandr --query | awk '$2 == "connected" && $1 !~ /^eDP/ { print $1 }' | sort
}

get_output_edid() {
  local output="$1"
  xrandr --prop | awk -v target="$output" '
    $1 == target { in_output = 1; in_edid = 0; next }
    in_output && $2 ~ /^(connected|disconnected)$/ { exit }
    in_output && $1 == "EDID:" { in_edid = 1; next }
    in_output && in_edid {
      if ($1 ~ /^[0-9a-fA-F]+$/) { printf "%s", tolower($1); next }
      exit
    }
  '
}

layout_for_external() {
  local output="$1"
  local edid pattern layout matched_layout

  edid="$(get_output_edid "$output")"

  if [[ -f "$monitor_layouts_file" ]]; then
    while read -r pattern layout _rest; do
      [[ -z "${pattern:-}" || "${pattern:0:1}" == "#" ]] && continue
      if [[ "$pattern" == "$output" || ( -n "$edid" && "$edid" == "$pattern"* ) ]]; then
        matched_layout="$layout"
      fi
    done <"$monitor_layouts_file"
  fi

  printf '%s\n' "${matched_layout:-$external_layout}"
}

restart_polybar() {
  [[ -x "$polybar_launcher" ]] || return 0
  bash "$polybar_launcher" >/tmp/polybar-hotplug-launch.log 2>&1 &
}

apply_external_layout() {
  [[ -x "$layout_script" ]] || return 0

  # Skip if a layout was just applied (e.g. by `dl` or a prior hotplug pass): a
  # redundant concurrent `layout.sh` would race xrandr/polybar and break the
  # wallpaper scaling / leave polybar on a single screen.
  if [[ -f /tmp/display-layout-applied ]]; then
    local age
    age="$(($(date +%s) - $(stat -c %Y /tmp/display-layout-applied 2>/dev/null || echo 0)))"
    [[ "$age" -lt 20 ]] && return 0
  fi

  local output layout
  output="$(current_externals | head -n 1)"
  [[ -z "$output" ]] && return 0

  layout="$(layout_for_external "$output")"
  bash "$layout_script" "$layout" "$output" >/dev/null 2>&1 || true
}

last_state="$(current_externals | tr '\n' ' ')"

if [[ -n "$last_state" ]]; then
  apply_external_layout
elif [[ -z "$last_state" ]]; then
  bash "$layout_script" recover >/dev/null 2>&1 || true
fi

check_once() {
  local next_state
  next_state="$(current_externals | tr '\n' ' ')"

  if [[ "$last_state" != "$next_state" ]]; then
    if [[ -n "$last_state" && -z "$next_state" ]]; then
      bash "$layout_script" recover >/dev/null 2>&1 || true
    elif [[ -n "$next_state" ]]; then
      apply_external_layout
    fi
    last_state="$next_state"
    restart_polybar
  fi
}

if [[ "$once" -eq 1 ]]; then
  check_once
  exit 0
fi

while true; do
  check_once
  sleep "$interval"
done
