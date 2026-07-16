#!/usr/bin/env bash
# 右键时钟:切换 iOS 音乐面板的开/关
set -euo pipefail
export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u)/bus"

PANEL="$HOME/.config/i3/panels/music-panel.js"

# 用命令行特征精确匹配本面板进程(避免误杀其它 gjs,如灵动岛 notification-daemon.js)
if pgrep -f "gjs .*music-panel.js" >/dev/null 2>&1; then
    pkill -f "gjs .*music-panel.js"
    exit 0
fi

setsid gjs "$PANEL" </dev/null >>/tmp/music-panel.log 2>&1 &
