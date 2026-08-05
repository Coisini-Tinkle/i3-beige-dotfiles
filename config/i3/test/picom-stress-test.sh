#!/usr/bin/env bash
# Picom animation stress test: window open/close + workspace switch
set -euo pipefail

PICOM_ORIG=/usr/bin/picom
PICOM_ANIM=/home/coisini/.local/bin/picom-ft
ANIM_CONF=/home/coisini/.config/picom/picom-anim.conf
FULL_CONF=/home/coisini/.config/picom/picom-full.conf

red()    { printf '\033[31m%s\033[0m\n' "$*"; }
green()  { printf '\033[32m%s\033[0m\n' "$*"; }
yellow() { printf '\033[33m%s\033[0m\n' "$*"; }
bold()   { printf '\033[1m%s\033[0m\n' "$*"; }
cyan()   { printf '\033[36m%s\033[0m\n' "$*"; }

cleanup() {
  echo
  echo "$(yellow 'Cleaning up...')"
  # Kill any leftover test terminals
  i3-msg '[class="^kitty-test$"] kill' 2>/dev/null || true
  kill $sample_pid 2>/dev/null || true
  if [ -n "${ORIG_RESTORE:-}" ]; then
    kill $(pgrep -f picom-ft) 2>/dev/null || true
    sleep 0.5
    $PICOM_ORIG --config "$FULL_CONF" --daemon 2>/dev/null
    sleep 1
    echo "$(green '✓') Original picom restored"
  fi
}
trap cleanup EXIT

echo
bold "========================================="
bold "  Picom Animation Stress Test"
bold "========================================="
echo "  CPU: $(grep 'model name' /proc/cpuinfo | head -1 | cut -d: -f2)"
echo

# ---- Switch to animated picom ----
echo "$(yellow '→') Starting picom-ft with animations..."
ORIG_PID=$(pgrep -f "^/usr/bin/picom" | head -1 || true)
if [ -n "$ORIG_PID" ]; then
  kill "$ORIG_PID" 2>/dev/null; sleep 0.5
  ORIG_RESTORE=1
fi
$PICOM_ANIM --config "$ANIM_CONF" --daemon 2>/dev/null
sleep 2
ANIM_PID=$(pgrep -f picom-ft | head -1)

if [ -z "$ANIM_PID" ]; then
  echo "$(red 'ERROR: picom-ft failed to start')"
  exit 1
fi
echo "  Animated picom PID: $ANIM_PID"

# CPU sampler (runs in background, samples every 0.25s)
sample_log=$(mktemp)
sample_pid=""
(
  while true; do
    cpu=$(ps -p "$ANIM_PID" -o %cpu= 2>/dev/null || echo "0")
    echo "$cpu" >> "$sample_log"
    sleep 0.25
  done
) &
sample_pid=$!

# ---- Test 1: window open/close burst ----
echo
echo "$(cyan 'Test 1:') Window open/close burst (50 windows)"
sleep 1
for i in $(seq 1 50); do
  i3-msg "exec kitty --class kitty-test -e sleep 0.3" 2>/dev/null
  sleep 0.05
done
# wait for all to close
sleep 2

# ---- Test 2: workspace switch rapid ----
echo "$(cyan 'Test 2:') Workspace rapid switch (40 switches)"
sleep 1
for i in $(seq 1 40); do
  ws=$(( (i % 10) + 1 ))
  i3-msg "workspace $ws" 2>/dev/null
  sleep 0.1
done
sleep 1

# ---- Test 3: mixed (open + switch simultaneously) ----
echo "$(cyan 'Test 3:') Mixed: open windows while switching workspaces"
sleep 1
for i in $(seq 1 30); do
  i3-msg "exec kitty --class kitty-test -e sleep 0.4" 2>/dev/null
  ws=$(( (i % 10) + 1 ))
  i3-msg "workspace $ws" 2>/dev/null
  sleep 0.08
done
sleep 2

# ---- Stop sampler ----
kill $sample_pid 2>/dev/null; wait $sample_pid 2>/dev/null
unset sample_pid

# ---- Analysis ----
samples=$(wc -l < "$sample_log")
max=$(sort -rn "$sample_log" | head -1)
avg=$(awk '{sum+=$1} END {printf "%.2f", sum/NR}' "$sample_log")

echo
bold "========================================="
echo "  STRESS TEST RESULTS"
echo "========================================="
printf "  %-25s %s\n" "Samples:" "$samples"
printf "  %-25s %s\n" "Maximum CPU spike:" "$(red "${max}%")"
printf "  %-25s %s\n" "Average CPU (all):" "$(green "${avg}%")"
echo
bold "========================================="

# Restore handled by trap
rm -f "$sample_log"
