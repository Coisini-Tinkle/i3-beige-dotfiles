#!/usr/bin/env bash
set -uo pipefail

config="${1:-$HOME/.config/i3/config}"
failed=0

check() {
  local description="$1"
  local pattern="$2"

  if grep -Eq "$pattern" "$config"; then
    printf 'PASS: %s\n' "$description"
  else
    printf 'FAIL: %s\n' "$description"
    failed=1
  fi
}

command -v flameshot >/dev/null 2>&1 || {
  printf 'FAIL: flameshot executable is unavailable\n'
  failed=1
}

check 'Flameshot daemon starts with i3' '^exec .*\/flameshot([[:space:]]|$)'
check 'Win+Shift+S launches Flameshot GUI on key release' '^bindcode --release \$mod\+Shift\+39 exec .*\/flameshot gui([[:space:]]|$)'

if i3 -C -c "$config" >/dev/null 2>&1; then
  printf 'PASS: i3 configuration syntax\n'
else
  printf 'FAIL: i3 configuration syntax\n'
  failed=1
fi

exit "$failed"
