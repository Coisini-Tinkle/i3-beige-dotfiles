#!/usr/bin/env bash
dir="$HOME/.config/kitty/img"
current="$HOME/.config/kitty/current-bg"
files=()
for f in "$dir"/*; do
    [[ -f "$f" ]] && files+=("$f")
done
if (( ${#files[@]} > 0 )); then
    current_target="$(readlink -f "$current" 2>/dev/null || true)"
    candidates=()
    for f in "${files[@]}"; do
        [[ "$(readlink -f "$f")" != "$current_target" ]] && candidates+=("$f")
    done
    (( ${#candidates[@]} > 0 )) || candidates=("${files[@]}")

    selected="${candidates[RANDOM % ${#candidates[@]}]}"
    ln -sf "$selected" "$current"

    if [[ "$TERM" == "xterm-kitty" ]] && command -v kitty >/dev/null 2>&1; then
        kitty @ set-background-image --all --configured --no-response --layout configured "$selected" >/dev/null 2>&1 || true
    fi
fi
