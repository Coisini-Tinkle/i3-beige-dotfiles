#!/usr/bin/env bash
set -euo pipefail

workspace_routing_script="${HOME}/.config/i3/workspace-routing.sh"
monitor_layouts_file="${HOME}/.config/i3/display-layouts.conf"
polybar_launcher="${HOME}/.config/polybar/launch.sh"

usage() {
  cat <<'EOF'
用法:
  display-layout.sh
  display-layout.sh menu
  display-layout.sh above [EXTERNAL]
  display-layout.sh left [EXTERNAL]
  display-layout.sh right [EXTERNAL]
  display-layout.sh external-only [EXTERNAL]
  display-layout.sh mirror [EXTERNAL]
  display-layout.sh recover
  display-layout.sh laptop-only
  display-layout.sh --print menu
  display-layout.sh --print above [EXTERNAL]
  display-layout.sh --print left [EXTERNAL]
  display-layout.sh --print right [EXTERNAL]
  display-layout.sh --print external-only [EXTERNAL]
  display-layout.sh --print mirror [EXTERNAL]
  display-layout.sh --print recover
  display-layout.sh --print laptop-only

模式:
  menu          打开中文交互菜单
  above         外屏在上，内屏在下
  left          外屏在左，内屏在右
  right         外屏在右，内屏在左
  external-only 仅使用外接屏幕
  mirror        镜像显示
  recover       强制恢复为仅内屏，并把工作区移回内屏
  laptop-only   仅使用笔记本屏幕

参数:
  EXTERNAL      可选，指定外接显示器输出名，例如 HDMI-2
EOF
}

have_cmd() {
  command -v "$1" >/dev/null 2>&1
}

detect_displays() {
  internal="$(xrandr --query | awk '$2 == "connected" && $1 ~ /^eDP/ { print $1; exit }')"
  if [[ -z "$internal" ]]; then
    echo "未能检测到笔记本内屏（预期类似 eDP-1）。" >&2
    exit 1
  fi

  mapfile -t known_outputs < <(xrandr --query | awk '/^(eDP|DP|HDMI|VGA|DVI|LVDS)/ { print $1 }')
  mapfile -t externals < <(xrandr --query | awk -v internal="$internal" '$2 == "connected" && $1 != internal { print $1 }')
}

validate_external() {
  local candidate="$1"
  local output
  for output in "${externals[@]}"; do
    if [[ "$output" == "$candidate" ]]; then
      return 0
    fi
  done
  echo "外接显示器 '$candidate' 当前并未连接。" >&2
  exit 1
}

pick_external() {
  if [[ -n "$external_arg" ]]; then
    validate_external "$external_arg"
    echo "$external_arg"
    return 0
  fi
  if [[ "${#externals[@]}" -eq 0 ]]; then
    echo "当前未检测到外接显示器。" >&2
    exit 1
  fi
  echo "${externals[0]}"
}

build_cmd() {
  local selected_mode="$1"
  local selected_external="${2:-}"

  case "$selected_mode" in
    above)
      cmd=(
        xrandr
        --output "$selected_external" --auto --primary
        --output "$internal" --auto --below "$selected_external"
      )
      ;;
    left)
      cmd=(
        xrandr
        --output "$selected_external" --auto --primary
        --output "$internal" --auto --right-of "$selected_external"
      )
      ;;
    right)
      cmd=(
        xrandr
        --output "$selected_external" --auto --primary
        --output "$internal" --auto --left-of "$selected_external"
      )
      ;;
    external-only)
      cmd=(
        xrandr
        --output "$selected_external" --auto --primary
        --output "$internal" --off
      )
      ;;
    mirror)
      cmd=(
        xrandr
        --output "$selected_external" --auto --primary
        --output "$internal" --auto --same-as "$selected_external"
      )
      ;;
    laptop-only)
      cmd=(xrandr --output "$internal" --auto --primary)
      local output
      for output in "${known_outputs[@]}"; do
        [[ "$output" == "$internal" ]] && continue
        cmd+=(--output "$output" --off)
      done
      ;;
    *)
      echo "未知模式: $selected_mode" >&2
      exit 1
      ;;
  esac
}

print_cmd() {
  printf '%q ' "${cmd[@]}"
  printf '\n'
}

run_cmd() {
  print_cmd
  if [[ "$print_only" -eq 0 ]]; then
    "${cmd[@]}"
  fi
}

apply_workspace_routing() {
  [[ "$print_only" -eq 1 ]] && return 0
  [[ ! -f "$workspace_routing_script" ]] && return 0

  case "$1" in
    above|left|right)
      bash "$workspace_routing_script" auto --reload-if-changed --normalize >/dev/null 2>&1 || true
      ;;
    external-only|mirror)
      bash "$workspace_routing_script" single "$2" --reload-if-changed --normalize >/dev/null 2>&1 || true
      ;;
    laptop-only|recover)
      bash "$workspace_routing_script" single "$internal" --reload-if-changed --normalize >/dev/null 2>&1 || true
      ;;
  esac
}

restart_polybar() {
  [[ "$print_only" -eq 1 ]] && return 0
  if command -v feh >/dev/null 2>&1; then
    feh --no-fehbg --bg-fill ~/.config/i3/themes/beige/wallpaper.png >/tmp/display-layout-wallpaper.log 2>&1 || true
  fi

  [[ -x "$polybar_launcher" ]] || return 0

  bash "$polybar_launcher" >/tmp/polybar-display-layout.log 2>&1 &
}

get_output_edid() {
  local output="$1"
  xrandr --prop | awk -v target="$output" '
    $1 == target { in_output = 1; in_edid = 0; next }
    in_output && $2 ~ /^(connected|disconnected)$/ { exit }
    in_output && $1 == "EDID:" { in_edid = 1; next }
    in_output && in_edid {
      if ($1 ~ /^[0-9a-fA-F]+$/) { printf "%s", tolower($1); next }
      exit
    }
  '
}

remember_external_layout() {
  [[ "$print_only" -eq 1 ]] && return 0

  local mode="$1"
  local output="${2:-}"
  local edid tmp_file

  case "$mode" in
    above|left|right|external-only|mirror) ;;
    *) return 0 ;;
  esac

  [[ -z "$output" ]] && return 0
  edid="$(get_output_edid "$output")"
  [[ -z "$edid" ]] && return 0

  mkdir -p "$(dirname "$monitor_layouts_file")"
  tmp_file="$(mktemp)"

  if [[ -f "$monitor_layouts_file" ]]; then
    awk -v edid="$edid" '$1 != edid { print }' "$monitor_layouts_file" >"$tmp_file"
  else
    {
      printf '# Display layout rules: EDID_OR_OUTPUT_NAME LAYOUT\n'
      printf '# Layout values are display-layout.sh modes: right, left, above, mirror, external-only.\n'
    } >"$tmp_file"
  fi

  printf '%s %s\n' "$edid" "$mode" >>"$tmp_file"
  mv "$tmp_file" "$monitor_layouts_file"
}

normalize_menu_mode() {
  case "$1" in
    上方) echo "above" ;;
    左侧) echo "left" ;;
    右侧) echo "right" ;;
    仅内屏) echo "laptop-only" ;;
    仅外屏) echo "external-only" ;;
    镜像) echo "mirror" ;;
    *)
      echo "未知菜单选项: $1" >&2
      exit 1
      ;;
  esac
}

menu_pick_external() {
  if [[ "${#externals[@]}" -eq 0 ]]; then
    selected_external=""
    return 0
  fi

  if [[ "${#externals[@]}" -eq 1 ]]; then
    selected_external="${externals[0]}"
    return 0
  fi

  local items=()
  local output
  for output in "${externals[@]}"; do
    items+=("$output" "已连接的外接显示器")
  done

  selected_external="$(
    whiptail \
      --title "显示布局" \
      --menu "选择外接显示器" \
      18 70 8 \
      "${items[@]}" \
      3>&1 1>&2 2>&3
  )" || return 1
}

menu_pick_mode() {
  local prompt="请选择布局"
  local options=(
    "上方" "外屏在上，内屏在下"
    "左侧" "外屏在左，内屏在右"
    "右侧" "外屏在右，内屏在左"
    "仅内屏" "仅使用笔记本屏幕"
    "仅外屏" "仅使用外接屏幕"
    "镜像" "内屏与外屏显示相同内容"
  )

  if [[ -z "$selected_external" ]]; then
    prompt="当前未检测到外接显示器"
    options=("仅内屏" "仅使用笔记本屏幕")
  fi

  selected_mode="$(
    whiptail \
      --title "显示布局" \
      --menu "$prompt" \
      20 78 10 \
      "${options[@]}" \
      3>&1 1>&2 2>&3
  )" || return 1
}

menu_confirm() {
  local preview
  preview="$(printf '%q ' "${cmd[@]}")"

  whiptail \
    --title "确认应用显示布局" \
    --yesno "将执行以下显示布局命令，是否继续？\n\n$preview" \
    14 90
}

run_menu() {
  if ! have_cmd whiptail; then
    echo "交互菜单依赖 whiptail，但当前系统未安装。" >&2
    exit 1
  fi

  menu_pick_external || exit 1
  menu_pick_mode || exit 1

  selected_mode="$(normalize_menu_mode "$selected_mode")"

  if [[ "$selected_mode" == "laptop-only" ]]; then
    build_cmd "$selected_mode"
  else
    build_cmd "$selected_mode" "$selected_external"
  fi

  if [[ "$print_only" -eq 1 ]]; then
    print_cmd
    exit 0
  fi

  menu_confirm || exit 0
  "${cmd[@]}"
  apply_workspace_routing "$selected_mode" "$selected_external"
  remember_external_layout "$selected_mode" "$selected_external"
  restart_polybar
}

print_only=0
if [[ "${1:-}" == "--print" ]]; then
  print_only=1
  shift
fi

mode="${1:-menu}"
external_arg="${2:-}"

detect_displays

selected_external=""
selected_mode=""
cmd=()

case "$mode" in
  menu)
    run_menu
    ;;
  above)
    external="$(pick_external)"
    build_cmd above "$external"
    run_cmd
    apply_workspace_routing above "$external"
    remember_external_layout above "$external"
    restart_polybar
    ;;
  left)
    external="$(pick_external)"
    build_cmd left "$external"
    run_cmd
    apply_workspace_routing left "$external"
    remember_external_layout left "$external"
    restart_polybar
    ;;
  right)
    external="$(pick_external)"
    build_cmd right "$external"
    run_cmd
    apply_workspace_routing right "$external"
    remember_external_layout right "$external"
    restart_polybar
    ;;
  external-only)
    external="$(pick_external)"
    build_cmd external-only "$external"
    run_cmd
    apply_workspace_routing external-only "$external"
    remember_external_layout external-only "$external"
    restart_polybar
    ;;
  mirror)
    external="$(pick_external)"
    build_cmd mirror "$external"
    run_cmd
    apply_workspace_routing mirror "$external"
    remember_external_layout mirror "$external"
    restart_polybar
    ;;
  recover)
    build_cmd laptop-only
    run_cmd
    if [[ "$print_only" -eq 0 ]]; then
      apply_workspace_routing recover
      restart_polybar
    fi
    ;;
  laptop-only)
    build_cmd laptop-only
    run_cmd
    apply_workspace_routing laptop-only
    restart_polybar
    ;;
  *)
    usage
    exit 1
    ;;
esac
