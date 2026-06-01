#!/usr/bin/env bash
set -euo pipefail

workspace="${1:-}"
if [[ -z "$workspace" ]]; then
  echo "用法: switch-workspace-current-output.sh WORKSPACE" >&2
  exit 1
fi

if ! command -v i3-msg >/dev/null 2>&1 || ! command -v jq >/dev/null 2>&1; then
  i3-msg "workspace --no-auto-back-and-forth number \"$workspace\""
  exit 0
fi

current_output="$(
  i3-msg -t get_workspaces |
    jq -r '.[] | select(.focused == true) | .output' |
    head -n 1
)"

if [[ -z "$current_output" || "$current_output" == "null" ]]; then
  i3-msg "workspace --no-auto-back-and-forth number \"$workspace\""
  exit 0
fi

i3-msg "workspace --no-auto-back-and-forth number \"$workspace\"" >/dev/null
i3-msg "move workspace to output \"$current_output\"" >/dev/null
i3-msg "workspace --no-auto-back-and-forth number \"$workspace\"" >/dev/null
