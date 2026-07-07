#!/usr/bin/env bash
set -euo pipefail

export LC_ALL=C

legacy_ssid="$({ nmcli -t -f active,ssid dev wifi 2>/dev/null || true; } | sed -n 's/^yes://p' | head -n 1)"
radio_state="$(nmcli -t -f WIFI general 2>/dev/null || true)"
device_row="$(nmcli -t -f DEVICE,TYPE,STATE device status 2>/dev/null | awk -F: '$2 == "wifi" && $3 == "connected" { print; exit }')"
device="${device_row%%:*}"
connection=""

if [[ -n "$device" ]]; then
  connection="$(nmcli -g GENERAL.CONNECTION device show "$device" 2>/dev/null || true)"
fi

printf 'radio_state=%s\n' "$radio_state"
printf 'legacy_scan_ssid=%s\n' "${legacy_ssid:-<empty>}"
printf 'connected_device=%s\n' "${device:-<empty>}"
printf 'active_connection=%s\n' "${connection:-<empty>}"

[[ "$radio_state" == "enabled" ]]
[[ -n "$device" ]]
[[ -n "$connection" && "$connection" != "--" ]]

printf 'control center WiFi state probe: PASS\n'
