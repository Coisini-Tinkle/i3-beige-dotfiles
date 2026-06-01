#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "用法: switch-workspace-fixed-output.sh internal|external WORKSPACE_NUMBER" >&2
  exit 1
}

[[ $# -eq 2 ]] || usage
role="$1"
workspace_number="$2"
case "$workspace_number" in
  0) workspace_number="10" ;;
esac

case "$workspace_number" in
  1) workspace="1:I" ;;
  2) workspace="2:II" ;;
  3) workspace="3:III" ;;
  4) workspace="4:IV" ;;
  5) workspace="5:V" ;;
  6) workspace="6:VI" ;;
  7) workspace="7:VII" ;;
  8) workspace="8:VIII" ;;
  9) workspace="9:IX" ;;
  10) workspace="10:X" ;;
  *) workspace="$workspace_number" ;;
esac

log_file="/tmp/switch-workspace-fixed-output.log"

if ! command -v i3-msg >/dev/null 2>&1 || ! command -v jq >/dev/null 2>&1; then
  i3-msg "workspace \"$workspace\"" >/dev/null
  exit 0
fi

outputs_json="$(i3-msg -t get_outputs)"
workspaces_json="$(i3-msg -t get_workspaces)"
internal_output="$(jq -r '.[] | select(.active == true and (.name | test("^eDP"))) | .name' <<<"$outputs_json" | head -n 1)"
external_output="$(jq -r --arg internal "$internal_output" '.[] | select(.active == true and .name != "xroot-0" and .name != $internal) | .name' <<<"$outputs_json" | head -n 1)"

target_output=""
case "$role" in
  internal)
    target_output="$internal_output"
    ;;
  external)
    target_output="$external_output"
    ;;
  *)
    usage
    ;;
esac

if [[ -z "$target_output" || "$target_output" == "null" ]]; then
  target_output="$internal_output"
fi
if [[ -z "$target_output" || "$target_output" == "null" ]]; then
  target_output="$(jq -r '.[] | select(.active == true and .name != "xroot-0") | .name' <<<"$outputs_json" | head -n 1)"
fi

current_output="$(jq -r --arg name "$workspace" --argjson num "$workspace_number" '.[] | select(.name == $name or .num == $num) | .output' <<<"$workspaces_json" | head -n 1)"
focus_con_id="$(
  i3-msg -t get_tree |
    jq -r --arg name "$workspace" --argjson num "$workspace_number" '
      [
        recurse((.nodes + .floating_nodes)[]?)
        | select(.type == "workspace" and (.name == $name or .num == $num))
        | recurse((.nodes + .floating_nodes)[]?)
        | select(.type != "workspace" and (.window != null or (.window_properties.class // null) != null))
        | .id
      ]
      | first // empty
    '
)"

{
  printf '%s role=%s workspace=%s internal=%s external=%s target=%s current=%s con=%s\n' \
    "$(date '+%F %T')" "$role" "$workspace" "$internal_output" "$external_output" "$target_output" "$current_output" "$focus_con_id"
} >>"$log_file" 2>/dev/null || true

if [[ -z "$target_output" || "$target_output" == "null" ]]; then
  if [[ -n "$focus_con_id" ]]; then
    i3-msg "[con_id=$focus_con_id] focus" >/dev/null
  else
    i3-msg "workspace \"$workspace\"" >/dev/null
  fi
  exit 0
fi

if [[ -n "$focus_con_id" ]]; then
  i3-msg "[con_id=$focus_con_id] focus" >/dev/null
  if [[ -n "$current_output" && "$current_output" != "$target_output" ]]; then
    i3-msg "move workspace to output $target_output" >/dev/null
    i3-msg "focus output $target_output" >/dev/null
    i3-msg "[con_id=$focus_con_id] focus" >/dev/null
  fi
else
  i3-msg "focus output $target_output" >/dev/null
  i3-msg "workspace \"$workspace\"" >/dev/null
  i3-msg "move workspace to output $target_output" >/dev/null
  i3-msg "focus output $target_output" >/dev/null
  i3-msg "workspace \"$workspace\"" >/dev/null
fi
