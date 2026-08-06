#!/bin/sh
# picom-status.sh — polybar tail script: real-time picom compositor status icon
# Green  = running
# Yellow = activating
# Red    = failed
# Dim    = stopped

export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u)/bus"

INK="#20201d"
GREEN="#7c886d"
YELLOW="#b99a57"
RED="#b86a76"
DIM="#6f6a5c"

if [ -f "$HOME/.config/i3/themes/current/theme.conf" ]; then
    . "$HOME/.config/i3/themes/current/theme.conf"
    INK="${INK:-#20201d}"
    GREEN="${GREEN:-#7c886d}"
    YELLOW="${YELLOW:-#b99a57}"
    RED="${RED:-#b86a76}"
    DIM="${MUTED:-#6f6a5c}"
fi

get_state() {
    systemctl --user is-active picom.service 2>/dev/null || echo "inactive"
}

while true; do
    state=$(get_state)
    case "$state" in
        "active")
            echo "%{T6}%{F${GREEN}}󰎓%{F-}%{T-}"
            ;;
        "activating"|"reloading")
            echo "%{T6}%{F${YELLOW}}󰎓%{F-}%{T-}"
            ;;
        "failed")
            echo "%{T6}%{F${RED}}󰎓%{F-}%{T-}"
            ;;
        *)
            echo "%{T6}%{F${DIM}}󰎓%{F-}%{T-}"
            ;;
    esac
    sleep 5
done
