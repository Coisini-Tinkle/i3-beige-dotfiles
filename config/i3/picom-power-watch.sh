#!/usr/bin/env bash
set -euo pipefail

if ! command -v udevadm >/dev/null 2>&1; then
  echo "udevadm is unavailable; Picom power-state watching is disabled." >&2
  exit 0
fi

# udevadm blocks while idle; systemd restarts Picom only on an AC-state event.
udevadm monitor --property --subsystem-match=power_supply 2>/dev/null |
  while IFS= read -r line; do
    case "$line" in
      POWER_SUPPLY_ONLINE=*)
        systemctl --user try-restart picom.service
        ;;
    esac
  done
