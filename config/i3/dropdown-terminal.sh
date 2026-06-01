#!/usr/bin/env bash
set -euo pipefail

class="kitty-dropdown"
criteria="[class=\"^${class}$\"]"

if ! command -v i3-msg >/dev/null 2>&1; then
  exec kitty --class "$class"
fi

if ! command -v jq >/dev/null 2>&1; then
  exec kitty --class "$class"
fi

if i3-msg -t get_tree | jq -e --arg class "$class" '
  recurse((.nodes + .floating_nodes)[]?)
  | select((.window_properties.class // "") == $class)
' >/dev/null; then
  i3-msg "$criteria scratchpad show" >/dev/null
else
  kitty --class "$class" >/dev/null 2>&1 &
fi
