#!/usr/bin/env bash
set -euo pipefail

dest="org.freedesktop.Notifications"
path="/org/freedesktop/Notifications"
iface="org.freedesktop.Notifications"
daemon_pattern="^/usr/bin/gjs $HOME/.config/i3/notify/daemon.js\$"
panel_pattern="^gjs $HOME/.config/i3/notify/drop-panel.js "
started="$(date +%s)"

call() {
  gdbus call --session --dest "$dest" --object-path "$path" --method "$iface.$1" "${@:2}"
}

notification_id() {
  sed -E 's/.*uint32 ([0-9]+).*/\1/' <<<"$1"
}

notify() {
  local app="$1" title="$2" urgency="$3" timeout="$4"
  call Notify "$app" 0 '' "$title" 'notification daemon smoke test' '[]' \
    "{'urgency': <byte $urgency>}" "$timeout"
}

close_notification() {
  call CloseNotification "$1" >/dev/null
}

call GetServerInformation >/dev/null
[[ "$(pgrep -fc "$daemon_pattern")" -eq 1 ]]

low="$(notify smoke-low 'smoke: low urgency' 0 0)"
sleep 0.4
close_notification "$(notification_id "$low")"
sleep 0.4

normal="$(notify smoke-normal 'smoke: normal urgency' 1 0)"
sleep 0.4
close_notification "$(notification_id "$normal")"
sleep 0.4

critical="$(notify smoke-critical 'smoke: critical urgency' 2 0)"
sleep 0.4
close_notification "$(notification_id "$critical")"
sleep 0.4

active="$(notify smoke-active 'smoke: active' 1 800)"
queued_a="$(notify smoke-a 'smoke: queued a' 1 800)"
queued_b="$(notify smoke-b 'smoke: queued b' 1 800)"
merge_old="$(notify smoke-merge 'smoke: merge old' 1 800)"
merge_new="$(notify smoke-merge 'smoke: merge new' 1 800)"
dropped_trigger="$(notify smoke-c 'smoke: queue overflow' 1 800)"
sleep 1

logs="$(journalctl --user --since "@$started" --no-pager 2>/dev/null)"
rg -q 'urgency=0, hold=1800' <<<"$logs"
rg -q 'urgency=1, hold=3000' <<<"$logs"
rg -q 'urgency=2, hold=8000' <<<"$logs"
rg -q 'Merged queued notification' <<<"$logs"
rg -q 'Dropped queued notification' <<<"$logs"

for result in "$active" "$queued_a" "$queued_b" "$merge_old" "$merge_new" "$dropped_trigger"; do
  close_notification "$(notification_id "$result")" || true
done
sleep 2

[[ "$(pgrep -fc "$daemon_pattern")" -eq 1 ]]
[[ "$(pgrep -fc "$panel_pattern" || true)" -eq 0 ]]

printf 'notification daemon smoke test: PASS\n'
