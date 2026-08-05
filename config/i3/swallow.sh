#!/usr/bin/env bash
# i3 window swallowing — hide the terminal, run a GUI app,
# and restore the terminal when the app closes.
#
# Usage: swallow <command...>
# Example: swallow evince document.pdf
#          swallow eog photo.png
#          swallow gimp
#
# For TUI apps (nvim, htop), just run them directly in the terminal.
set -euo pipefail

if [[ $# -eq 0 ]]; then
  echo "Usage: swallow <command...>" >&2
  exit 1
fi

# Get the currently focused window ID (our terminal)
con_id=$(i3-msg -t get_tree | jq -r '
  recurse(.nodes[], .floating_nodes[])?
  | select(.focused == true)
  | .id
')

if [[ -z "$con_id" || "$con_id" == "null" ]]; then
  echo "swallow: could not find focused window" >&2
  exec "$@"
fi

# Hide terminal to scratchpad
i3-msg "[con_id=$con_id] move scratchpad" >/dev/null

# Wait a tick for i3 to process
sleep 0.15

# Run the GUI app in the background
"$@" &
cmd_pid=$!

# Wait for the GUI window to actually appear, then for the process to exit
wait $cmd_pid 2>/dev/null || true

# Small delay to let the window fully close
sleep 0.15

# Bring terminal back
i3-msg "[con_id=$con_id] scratchpad show" >/dev/null
