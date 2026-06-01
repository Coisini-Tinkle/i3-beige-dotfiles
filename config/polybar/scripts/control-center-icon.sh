#!/bin/sh

export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u)/bus"

FRAMES="▁▃▅ ▂▅▇ ▃▇█ ▅█▇ ▇█▅ █▇▃ ▇▅▂ ▅▃▁ ▃▁▂ ▁▂▃ ▂▃▅ ▃▅▇ ▅▇█ ▇█▅ █▅▃ ▇▃▂ ▅▂▁"
INTERVAL=0.4

is_muted() {
    wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null | grep -q MUTED
}

is_playing() {
    for f in /proc/asound/card*/pcm*/sub*/status; do
        if [ -f "$f" ] && ! grep -q "closed" "$f" 2>/dev/null; then
            return 0
        fi
    done
    return 1
}

while true; do
    if is_muted; then
        echo "󰝟"
        sleep 2
    elif is_playing; then
        for frame in $FRAMES; do
            echo "%{F#a7c080}${frame}%{F-}"
            sleep "$INTERVAL"
        done
    else
        echo "󰒘"
        sleep 2
    fi
done
