#!/bin/sh

export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u)/bus"

INK="#20201d"
GREEN="#8fb26e"
YELLOW="#b99a57"
RED="#b86a76"
DIM="#6f6a5c"

get_vm_state() {
    virsh --connect qemu:///system domstate win11 2>/dev/null || echo "error"
}

while true; do
    state=$(get_vm_state)
    case "$state" in
        "running")
            echo "%{T6}%{F${GREEN}}󰹑%{F-}%{T-}"
            ;;
        "shut off")
            echo "%{T6}%{F${DIM}}󰹑%{F-}%{T-}"
            ;;
        "paused")
            echo "%{T6}%{F${YELLOW}}󰹑%{F-}%{T-}"
            ;;
        *)
            echo "%{T6}%{F${RED}}󰹑%{F-}%{T-}"
            ;;
    esac
    sleep 30
done
