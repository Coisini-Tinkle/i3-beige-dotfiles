#!/usr/bin/env bash
set -euo pipefail

get_networks() {
  nmcli -t -f SSID,SIGNAL,SECURITY dev wifi list --rescan auto \
    | sort -t: -k2 -nr \
    | awk -F: '{
        sig = $2;
        sec = $3;
        ssid = $1;
        if (ssid == "") ssid = "(hidden)";
        bars = "";
        if (sig >= 80) bars = "▓▓▓▓";
        else if (sig >= 60) bars = "▓▓▓░";
        else if (sig >= 40) bars = "▓▓░░";
        else if (sig >= 20) bars = "▓░░░";
        else bars = "░░░░";
        lock = (sec != "" && sec != "--") ? " 󰌆" : "";
        printf "%-3s %s%s  %s\n", bars, ssid, lock, sig"%"
      }'
}

selected="$(get_networks | rofi -dmenu -i -p "WiFi" \
  -theme-str 'listview { lines: 10; }' 2>/dev/null)"

[[ -z "$selected" ]] && exit 0

ssid="$(echo "$selected" | sed 's/^[▓░ ]* //' | sed 's/ 󰌆.*//' | sed 's/  [0-9]*%$//' | xargs)"

if [[ "$ssid" == "(hidden)" ]]; then
  ssid="$(rofi -dmenu -p "SSID" 2>/dev/null)"
  [[ -z "$ssid" ]] && exit 0
fi

if nmcli dev wifi connect "$ssid" 2>/dev/null; then
  notify-send "WiFi" "已连接到 $ssid"
else
  pass="$(rofi -dmenu -password -p "密码 ($ssid)" 2>/dev/null)"
  [[ -z "$pass" ]] && exit 0
  if nmcli dev wifi connect "$ssid" password "$pass" 2>/dev/null; then
    notify-send "WiFi" "已连接到 $ssid"
  else
    notify-send -u critical "WiFi" "连接 $ssid 失败"
  fi
fi
