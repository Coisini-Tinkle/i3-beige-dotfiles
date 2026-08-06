#!/usr/bin/env bash
set -euo pipefail

export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u)/bus"

get_volume() {
    local vol
    vol=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null || echo "0.0")
    local pct
    pct=$(echo "$vol" | awk '{printf "%.0f", $2 * 100}')
    if echo "$vol" | grep -q MUTED; then
        echo "󰝟 ${pct}% (muted)"
    else
        echo "󰕾 ${pct}%"
    fi
}

get_bluetooth() {
    if rfkill list bluetooth 2>/dev/null | grep -q "Soft blocked: no"; then
        echo "󰂯 Bluetooth ON"
    else
        echo "󰂲 Bluetooth OFF"
    fi
}

get_wifi() {
    if [ "$(cat /sys/class/net/wlp0s20f3/operstate 2>/dev/null)" = "up" ]; then
        local ssid
        ssid=$(iwgetid -r 2>/dev/null || echo "connected")
        echo "󰤨 WiFi: ${ssid}"
    else
        echo "󰤭 WiFi OFF"
    fi
}

get_player() {
    local status
    status=$(playerctl status 2>/dev/null || echo "")
    if [ -z "$status" ] || [ "$status" = "No players found" ]; then
        echo "󰝛 No Player"
        return
    fi
    local artist title
    artist=$(playerctl metadata --format '{{artist}}' 2>/dev/null || echo "")
    title=$(playerctl metadata --format '{{title}}' 2>/dev/null || echo "")
    if [ -n "$artist" ]; then
        echo "󰝚 ${artist} - ${title}"
    else
        echo "󰝚 ${title}"
    fi
}

player_info=$(get_player)
player_status=$(playerctl status 2>/dev/null || echo "")
vol_status=$(get_volume)
bt_status=$(get_bluetooth)
wifi_status=$(get_wifi)

if [ "$player_status" = "Playing" ]; then
    toggle_label="󰏤 Pause"
else
    toggle_label="󰐊 Play"
fi

entries="${player_info}\n${vol_status}\n󰼧 Previous\n${bt_status}\n${toggle_label}\n${wifi_status}\n󰼨 Next\n󰌾 Lock Screen\n\n󰜉 Reboot\n\n󰐥 Shutdown"

selected="$(echo -e "$entries" | rofi -dmenu -i -p "" \
    -me-select-entry '' -me-accept-entry mouseprimary \
    -theme ~/.config/rofi/control-center.rasi \
    -theme-str 'listview { columns: 2; lines: 6; }' 2>/dev/null)"

case "$selected" in
    *muted*)              wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle ;;
    *Volume*[0-9]*)       wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle ;;
    *Bluetooth*ON*)       rfkill block bluetooth ;;
    *Bluetooth*OFF*)      rfkill unblock bluetooth ;;
    *WiFi*)               DISPLAY=:1 setsid bash ~/.config/i3/rofi/wifi.sh </dev/null >/dev/null 2>&1 & ;;
    *Previous*)           playerctl previous ;;
    *Play*)               playerctl play ;;
    *Pause*)              playerctl pause ;;
    *Next*)               playerctl next ;;
    *Lock*)               bash ~/.config/i3/lock.sh ;;
    *Reboot*)             systemctl reboot ;;
    *Shutdown*)           systemctl poweroff ;;
esac
