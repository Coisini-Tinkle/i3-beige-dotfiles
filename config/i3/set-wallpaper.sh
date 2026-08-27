#!/usr/bin/env bash
# set-wallpaper.sh <image> [<output-file>]
#
# 多屏壁纸修复：feh 默认按 Xinerama 逐屏填充，但在部分环境下会退化为把整张图
# 拉伸铺满「整块虚拟桌面」，导致某屏被过度放大/裁切、或（锁屏时）卡在两屏中间。
# 本脚本对每块屏做 cover 填充（自动填满该屏、裁掉溢出，无留白），预合成到虚拟桌面
# 画布，再用 `feh --no-xinerama` 1:1 铺设，保证每块屏都「自动填充」整张壁纸、互不干扰。
#
# 用法：
#   set-wallpaper.sh <image>             # 直接设置桌面壁纸
#   set-wallpaper.sh <image> <out.png>   # 仅把合成结果写入 out.png（供 i3lock 复用）
#
# 可调环境变量：
#   WALLPAPER_BG  显示器间未铺满区域（如错位布局）的底色，默认取壁纸平均色
set -euo pipefail

IMG="${1:-}"
OUT="${2:-}"
[[ -f "$IMG" ]] || { echo "set-wallpaper: 需要一个图片文件" >&2; exit 1; }

command -v feh >/dev/null 2>&1 || { echo "set-wallpaper: 未找到 feh" >&2; exit 1; }

# 设置壁纸或写出合成图
emit() {
  local img="$1"
  if [[ -n "$OUT" ]]; then
    cp "$img" "$OUT"
  else
    feh --no-fehbg --bg-fill --no-xinerama "$img" || true
  fi
}

# 无 convert 时退化为整屏拉伸（比逐屏像素填充更一致）
if ! command -v convert >/dev/null 2>&1; then
  emit "$IMG"
  exit 0
fi

# 图像原始尺寸
read -r IW IH < <(identify -format "%w %h" "$IMG" 2>/dev/null) || true
if [[ "${IW:-0}" -le 0 || "${IH:-0}" -le 0 ]]; then
  emit "$IMG"
  exit 0
fi

# 解析显示器：xrandr --listmonitors 形如
#   0: +*DP-1 1920/598x1080/336+0+0  DP-1
mons="$(xrandr --listmonitors 2>/dev/null | grep -E '^[[:space:]]*[0-9]+:')" || true
if [[ -z "$mons" ]]; then
  emit "$IMG"
  exit 0
fi

vw=0; vh=0; n=0
declare -a MX MY MW MH
while IFS= read -r line; do
  geom="$(awk '{print $3}' <<<"$line")"
  if [[ "$geom" =~ ([0-9]+)/[0-9]+x([0-9]+)/[0-9]+\+([0-9]+)\+([0-9]+) ]]; then
    w="${BASH_REMATCH[1]}"; h="${BASH_REMATCH[2]}"
    x="${BASH_REMATCH[3]}"; y="${BASH_REMATCH[4]}"
    MX[n]="$x"; MY[n]="$y"; MW[n]="$w"; MH[n]="$h"
    (( vw < x + w )) && vw=$((x + w))
    (( vh < y + h )) && vh=$((y + h))
    n=$((n + 1))
  fi
done <<< "$mons"

# 单屏：直接铺满
if [[ "$n" -le 1 ]]; then
  emit "$IMG"
  exit 0
fi

# 底色：默认取壁纸平均色，使错位布局的缝隙自然融合
BG="${WALLPAPER_BG:-$(convert "$IMG" -resize 1x1! -format '%[pixel:p{0,0}]' info: 2>/dev/null || echo '#000000')}"

TMP="$(mktemp /tmp/wallpaper-XXXXXX.png)"
TMP2="$(mktemp /tmp/wallpaper-XXXXXX.png)"
trap 'rm -f "$TMP" "$TMP2"' EXIT

# 虚拟桌面画布（底色）
convert -size "${vw}x${vh}" "xc:${BG}" "$TMP"

for ((i = 0; i < n; i++)); do
  x="${MX[i]}"; y="${MY[i]}"; w="${MW[i]}"; h="${MH[i]}"
  # cover 缩放：填满该屏，较长边裁掉
  s="$(awk -v iw="$IW" -v ih="$IH" -v w="$w" -v h="$h" \
    'BEGIN{printf "%.6f", (w/iw > h/ih) ? w/iw : h/ih}')"
  rw_px="$(awk -v iw="$IW" -v s="$s" 'BEGIN{printf "%d", iw*s + 0.5}')"
  rh_px="$(awk -v ih="$IH" -v s="$s" 'BEGIN{printf "%d", ih*s + 0.5}')"
  # 居中裁到该屏矩形，避免溢出污染相邻屏
  crop_x="$(awk -v a="$rw_px" -v b="$w" 'BEGIN{printf "%d", (a-b)/2}')"
  crop_y="$(awk -v a="$rh_px" -v b="$h" 'BEGIN{printf "%d", (a-b)/2}')"
  convert "$TMP" \
    \( "$IMG" -resize "${rw_px}x${rh_px}!" -crop "${w}x${h}+${crop_x}+${crop_y}" +repage \) \
    -geometry "+${x}+${y}" -composite "$TMP2"
  mv "$TMP2" "$TMP"
done

emit "$TMP"
