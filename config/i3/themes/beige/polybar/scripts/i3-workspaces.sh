#!/usr/bin/env bash
# Per-monitor i3 workspace indicator for polybar.
#   focused  -> ink capsule (powerline caps + ink bg)   当前工作区
#   occupied -> ink dot ●                               有窗口未聚焦
#   empty    -> dim dash –                              空工作区
#   urgent   -> red dot ●
# Slots = workspaces routed to THIS bar's monitor ($MONITOR), read from the
# routing file, so it tracks the split/single-screen layout automatically.
# Clicking a symbol switches to that workspace.
# tail = true: renders once, then re-renders on every i3 workspace/window event.

set -u

ROUTING="$HOME/.config/i3/workspace-output-routing.conf"

INK="#1a1a1a"
DIM="#6a6258"
RED="#ca7081"

CAP_FONT=5          # %{T5} = font-4 (size=9) caps -> extra-slim capsule
SYM_FONT=2          # %{T2} = font-1 (size=14) = dots / dash

CAP_L=$''     # left half-circle (thick)
CAP_R=$''     # right half-circle (thick)
DOT="●"
DASH="–"

MON="${MONITOR:-}"

# Fixed slots for this monitor (workspace names), in routing-file order.
read_slots() {
  local _ q rest out name
  while read -r _ q rest; do
    out="${rest##* }"
    name="${q%\"}"; name="${name#\"}"
    if [[ -z "$MON" || "$out" == "$MON" ]]; then
      printf '%s\n' "$name"
    fi
  done < <(grep '^workspace ' "$ROUTING" 2>/dev/null)
}

render() {
  local ws_json tree_json
  ws_json="$(i3-msg -t get_workspaces 2>/dev/null)" || return
  tree_json="$(i3-msg -t get_tree 2>/dev/null)" || return

  declare -A FOCUSED URGENT OCC
  local nm fc ur cnt
  while IFS=$'\t' read -r nm fc ur; do
    FOCUSED["$nm"]="$fc"; URGENT["$nm"]="$ur"
  done < <(jq -r '.[] | [.name, (.focused|tostring), (.urgent|tostring)] | @tsv' <<<"$ws_json" 2>/dev/null)
  while IFS=$'\t' read -r nm cnt; do
    OCC["$nm"]="$cnt"
  done < <(jq -r '
    [.. | objects | select(.type=="workspace")] | .[]
    | [.name, ([recurse(.nodes[]?, .floating_nodes[]?) | select(.window != null)] | length)] | @tsv
  ' <<<"$tree_json" 2>/dev/null)

  local out="" name num act
  while read -r name; do
    [[ -z "$name" ]] && continue
    num="${name%%:*}"
    act="i3-msg workspace number ${num}"
    if [[ "${FOCUSED[$name]:-false}" == "true" ]]; then
      # capsule = left cap + solid block(s) + right cap, all glyph-rendered (no %{B}) so heights align
      out+="%{A1:${act}:}%{T${CAP_FONT}}%{F${INK}}${CAP_L}█%{O-1px}█%{O-1px}█${CAP_R}%{F-}%{T-}%{A} "
    elif [[ "${URGENT[$name]:-false}" == "true" ]]; then
      out+="%{A1:${act}:}%{T${SYM_FONT}}%{F${RED}}${DOT}%{F-}%{T-}%{A} "
    elif [[ "${OCC[$name]:-0}" -gt 0 ]]; then
      out+="%{A1:${act}:}%{T${SYM_FONT}}%{F${INK}}${DOT}%{F-}%{T-}%{A} "
    else
      out+="%{A1:${act}:}%{T${SYM_FONT}}%{F${DIM}}${DASH}%{F-}%{T-}%{A} "
    fi
  done < <(read_slots)

  printf '%s\n' "${out% }"
}

render
# Re-render on every workspace/window change; re-subscribe if the stream drops.
trap 'exit 0' TERM INT
while true; do
  i3-msg -t subscribe -m '[ "workspace", "window" ]' 2>/dev/null | while read -r _; do
    render
  done
  sleep 1
done
