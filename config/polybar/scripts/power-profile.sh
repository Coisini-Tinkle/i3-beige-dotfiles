#!/bin/sh

export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u)/bus"

PROFILES="performance balanced power-saver"
ICONS="󰓎 󰾐 󰢠"
LABELS="性能 均衡 省电"
COLORS="#e67e80 #dbbc7f #7fbbb3"
INK="#1a1a1a"

if [ -f "$HOME/.config/i3/themes/current/theme.conf" ]; then
    # shellcheck source=/dev/null
    . "$HOME/.config/i3/themes/current/theme.conf"
    INK="${INK:-#1a1a1a}"
    COLORS="${RED:-#e67e80} ${YELLOW:-#dbbc7f} ${CYAN:-#7fbbb3}"
fi

get_current() {
    powerprofilesctl get
}

get_index() {
    current=$(get_current)
    i=0
    for p in $PROFILES; do
        if [ "$p" = "$current" ]; then
            echo $i
            return
        fi
        i=$((i + 1))
    done
    echo 1
}

next_profile() {
    idx=$(get_index)
    idx=$((idx + 1))
    count=0
    for p in $PROFILES; do
        count=$((count + 1))
    done
    if [ "$idx" -ge "$count" ]; then
        idx=0
    fi
    i=0
    for p in $PROFILES; do
        if [ "$i" = "$idx" ]; then
            powerprofilesctl set "$p"
            return
        fi
        i=$((i + 1))
    done
}

print_status() {
    idx=$(get_index)
    ci=0
    icon=""
    for ic in $ICONS; do
        if [ "$ci" = "$idx" ]; then
            icon=$ic
        fi
        ci=$((ci + 1))
    done
    ci=0
    for c in $COLORS; do
        if [ "$ci" = "$idx" ]; then
            color=$c
        fi
        ci=$((ci + 1))
    done
    i=0
    label=""
    for l in $LABELS; do
        if [ "$i" = "$idx" ]; then
            label=$l
        fi
        i=$((i + 1))
    done
    echo "%{F${INK}}${icon} ${label}%{F-}"
}

case "$1" in
    --toggle)
        next_profile
        print_status
        ;;
    *)
        print_status
        ;;
esac
