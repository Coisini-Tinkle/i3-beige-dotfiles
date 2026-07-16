#!/usr/bin/env bash
# 左键时钟:切换 iOS 控制中心面板的开/关
set -euo pipefail
export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u)/bus"

PANEL="$HOME/.config/i3/control-center.js"

if pgrep -f "gjs .*control-center.js" >/dev/null 2>&1; then
    pkill -f "gjs .*control-center.js"
    exit 0
fi

setsid gjs "$PANEL" </dev/null >>/tmp/control-center.log 2>&1 &
