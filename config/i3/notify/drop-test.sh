#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

exec gjs "$script_dir/notify/drop-panel.js" \
  --title "${1:-下拉动画测试}" \
  --body "${2:-从 polybar 下沿展开，然后自动收回}" \
  --progress "${3:-68}"
