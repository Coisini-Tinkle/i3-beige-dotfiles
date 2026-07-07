#!/usr/bin/env bash
set -euo pipefail

# udevadm blocks while idle; systemd restarts Picom only on an AC-state event.
udevadm monitor --property --subsystem-match=power_supply 2>/dev/null |
  while IFS= read -r line; do
    case "$line" in
      POWER_SUPPLY_ONLINE=*)
        systemctl --user try-restart picom.service
        ;;
    esac
  done
