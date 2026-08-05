#!/usr/bin/env bash
# CPU comparison: picom (original) vs picom-ft (animated)
# Measures idle CPU usage of both compositors for 15 seconds each.
set -euo pipefail

PICOM_ORIG=/usr/bin/picom
PICOM_ANIM=/home/coisini/.local/bin/picom-ft
ANIM_CONF=/home/coisini/.config/picom/picom-anim.conf
FULL_CONF=/home/coisini/.config/picom/picom-full.conf
DURATION=15

red()    { printf '\033[31m%s\033[0m\n' "$*"; }
green()  { printf '\033[32m%s\033[0m\n' "$*"; }
yellow() { printf '\033[33m%s\033[0m\n' "$*"; }
bold()   { printf '\033[1m%s\033[0m\n' "$*"; }

sample_cpu() {
  local pid=$1 label=$2
  echo "  Sampling $label (PID $pid) for ${DURATION}s..."
  local total=0 count=0
  local end=$((SECONDS + DURATION))
  while [ $SECONDS -lt $end ]; do
    local cpu
    cpu=$(ps -p "$pid" -o %cpu= 2>/dev/null || echo "0")
    total=$(echo "$total + $cpu" | bc)
    count=$((count + 1))
    sleep 0.5
  done
  local avg
  avg=$(echo "scale=2; $total / $count" | bc)
  echo "$avg"
}

echo
bold "========================================="
bold "  Picom CPU Comparison Test"
bold "========================================="
echo
echo "System info:"
echo "  CPU: $(grep 'model name' /proc/cpuinfo | head -1 | cut -d: -f2)"
echo "  Cores: $(nproc)"
echo "  Power: $(cat /sys/class/power_supply/ADP1/online 2>/dev/null && echo 'AC' || echo 'Battery')"
echo "  Picom original: $($PICOM_ORIG --version 2>&1 | head -1)"
echo "  Picom animated: $($PICOM_ANIM --version 2>&1)"
echo

# ---- Test 1: original picom ----
echo "$(yellow 'Test 1:') Original picom (idle)"
ORIG_PID=$(pgrep -x picom | head -1 || true)
ORIG_WAS_RUNNING=false
if [ -n "$ORIG_PID" ]; then
  ORIG_WAS_RUNNING=true
  orig_cpu=$(sample_cpu "$ORIG_PID" "picom original")
  echo "  Average CPU: ${orig_cpu}%"
else
  orange "  No picom running, starting temporarily..."
  $PICOM_ORIG --config "$FULL_CONF" --daemon 2>/dev/null
  sleep 2
  ORIG_PID=$(pgrep -x picom | head -1)
  orig_cpu=$(sample_cpu "$ORIG_PID" "picom original")
  echo "  Average CPU: ${orig_cpu}%"
  kill "$ORIG_PID" 2>/dev/null || true
  sleep 0.5
fi

# ---- Test 2: animated picom-ft ----
echo
echo "$(yellow 'Test 2:') Picom-ft-labs animated (idle)"

# Kill original if it was restarted by us, or temporarily replace it
if $ORIG_WAS_RUNNING; then
  kill "$ORIG_PID" 2>/dev/null || true
  sleep 0.5
fi

$PICOM_ANIM --config "$ANIM_CONF" --daemon 2>/dev/null
sleep 2
ANIM_PID=$(pgrep -x picom | head -1)
anim_cpu=$(sample_cpu "$ANIM_PID" "picom-ft animated")
echo "  Average CPU: ${anim_cpu}%"

# ---- Restore original picom ----
kill "$ANIM_PID" 2>/dev/null || true
sleep 0.5
if $ORIG_WAS_RUNNING; then
  $PICOM_ORIG --config "$FULL_CONF" --daemon 2>/dev/null
  sleep 1
  echo
  echo "$(green '✓') Original picom restored"
else
  echo
  echo "$(yellow '!') Original picom was not running — left stopped"
fi

# ---- Summary ----
echo
bold "========================================="
printf "  %-30s %s\n" "Original picom (idle):" "$(green "${orig_cpu}%")"
printf "  %-30s %s\n" "Picom-ft animated (idle):" "$(red "${anim_cpu}%")"
echo
diff=$(echo "scale=2; $anim_cpu - $orig_cpu" | bc)
pct=$(echo "scale=0; ($diff / $orig_cpu) * 100" | bc 2>/dev/null || echo "N/A")
echo "  CPU increase: ${diff} percentage points (~${pct}% relative)"
echo
bold "========================================="
