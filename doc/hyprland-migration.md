# Hyprland 共存迁移方案（最小可跑骨架）

> 目标：在保留现有 X11/i3 工作环境不动的前提下，新增一套可独立登录的 Hyprland/Wayland 桌面，用于折腾。
> 本方案所有新增文件都在 `config/hypr/`、`config/waybar/`、`config/kanshi/`，**不修改任何 i3/polybar 文件**。

## 硬件现实

- 本机为 **Intel UHD（CometLake，主显示）+ NVIDIA MX350（GP107M，PRIME 独显）**。
- Hyprland 跑在 **Intel 核显** 上；MX350 仅做按需 offload（`prime-run`）。
- 闭源驱动 535 + `libnvidia-egl-wayland1` 已就绪，无需重装驱动。
- 因走 Intel 核显，Hyprland 本身几乎不受 NVIDIA 坑（hardware cursor / EGL）影响。

## 唯一系统级改动（需重启、可逆）

为正确启用 PRIME/EGL：

```
/etc/default/grub  →  GRUB_CMDLINE_LINUX_DEFAULT 追加 nvidia-drm.modeset=1
sudo update-grub
reboot
```

可逆：删掉参数再 `update-grub` 即可。其余全部在 `~/.config` 与 dotfiles 仓库内。

## 工具选型（主流组合）

| 用途                | X11(i3)                  | Wayland(Hyprland)                  |
| ------------------- | ------------------------ | ---------------------------------- |
| 窗口管理            | i3                       | Hyprland                           |
| 状态栏              | polybar                  | waybar                             |
| 壁纸                | feh（合成画布）          | swaybg（逐屏 fill，静态）          |
| 锁屏                | i3lock-color             | swaylock                           |
| 多屏布局            | xrandr 脚本              | hyprland.conf monitor 行 / kanshi  |
| 启动器              | rofi                     | wofi（Wayland 原生，源内可直接装） |
| 截图                | flameshot                | flameshot（已支持 Wayland）        |
| 剪贴/通知/输入/终端 | copyq/dunst/fcitx5/kitty | 同左（通用）                       |

> ⚠️ **Ubuntu 24.04 默认源不含 `hyprland`**（窗口管理器本体必须源码编译），但其余配套几乎都能从 `apt` 直装：`waybar`、`kanshi`、`wofi`、`grim`、`slurp`、`wl-clipboard`、`swaybg`（静态壁纸）、`swaylock`（锁屏）、`xdg-desktop-portal-wlr`（通用 portal 后端）。
>
> 因此本方案把原计划的 `swww`/`hyprlock`（这俩 GitHub 也只发源码、需各自编译）替换为源内的 `swaybg`/`swaylock`，既贴合「阶段优先做静态壁纸」的决策，又只需编译 **Hyprland 一个** 即可进桌面。后续若想要动画壁纸/更花哨锁屏，可再源码编译 swww/hyprlock 替换回来。

## 目录结构（仓库内新增）

```
config/hypr/
  hyprland.conf            # 主配置：monitor/env/binds/exec-once/gaps/门窗规则
  env.conf                 # fcitx5 + portal 环境变量（被 hyprland.conf include）
  scripts/
    set-wallpaper-hypr.sh  # swaybg 版，对每块屏独立 fill
    autotiling.sh          # hyprland 版自动平铺（缺 pyautotiling 时 no-op）
config/waybar/
  config.jsonc             # 模块：workspaces/clock/battery/network/tray/menu
  style.css                # 复用 beige 色板
config/kanshi/
  config.kanshi            # 静态多屏布局（热插拔阶段再用）
```

`install.sh` 的 `apps` 数组追加 `hypr waybar kanshi`（仅新增，原逻辑零改动）。

## 分阶段实施

### 阶段 1 — 能进桌面

- `hyprland.conf` 最小集：`monitor=,preferred,auto,1`（自动多屏）、`exec-once` 启动 waybar/swaybg/fcitx5/dex、`env` 设 fcitx5 + portal、`$mod` 键位对齐 i3（Mod4 + hjkl + 数字切换 workspace）。
- 登录选 `Hyprland` session，确认能进、键位可用。

### 阶段 2 — 静态多屏壁纸（重灾区，先静态）

- `set-wallpaper-hypr.sh`：用 `swaybg -o <每块屏> -i <同一图> -m fill`，swaybg 每块屏独立 fill（静态，但不需要 xrandr 合成画布）。
- `hyprland.conf` 里 `exec-once` 调 `set-wallpaper-hypr.sh`。
- 热插拔自动切换留到下一轮（kanshi / monitor 事件）。

### 阶段 3 — waybar

- 移植 polybar 核心模块：workspaces（wlr/workspaces）、clock、battery、network、tray、menu（点开 wofi）。
- `style.css` 直接复用 beige 色板（`#e5e1c8` 底 / `#20201d` 字 / `#6d8d87` 强调）。
- 跳过：picom-status（hyprland 无 picom）、vm-status/control-center（后续迭代）。

### 阶段 4 — 锁屏 + 输入

- `swaylock`：源内直接装，`$mainMod+L` 调用；想要 hyprlock 风格再源码编译替换。
- fcitx5：在 `env.conf` 设 `GTK_IM_MODULE/QT_IM_MODULE/XMODIFIERS=fcitx` + `exec-once = fcitx5 -d`，验证中文输入。

## 风险与回退

| 风险                          | 缓解                                                                             |
| ----------------------------- | -------------------------------------------------------------------------------- |
| 进不去 Hyprland（显卡/PRIME） | 登录界面保留 i3 入口；不卸载任何 X11 组件                                        |
| fcitx5 中文失效               | env.conf 单独隔离，仅影响 hyprland 会话                                          |
| swaybg 静态无动画             | 阶段优先静态；想要动画壁纸再源码编译 swww 替换                                   |
| 误改 i3                       | 本方案不碰 i3 文件，`git` 仅新增 `config/hypr`、`config/waybar`、`config/kanshi` |

## 验证清单

- [ ] 阶段1：`Hyprland` 登录后 `hyprctl monitors` 看到双屏、`hyprctl clients` 正常
- [ ] 阶段2：双屏各自原生分辨率、壁纸 fill 无拉伸；`hyprctl monitors` 布局正确
- [ ] 阶段3：waybar 双屏显示、点击 menu 弹 wofi
- [ ] 阶段4：`swaylock` 锁屏正常；fcitx5 能打中文
- [ ] GRUB：`cat /proc/cmdline` 含 `nvidia-drm.modeset=1`

## 安装命令（Ubuntu 24.04）

```bash
# 1) 源内包（apt 直装，无需编译）
sudo apt update
sudo apt install -y waybar kanshi wofi swaybg swaylock \
  grim slurp wl-clipboard xdg-desktop-portal-wlr \
  jq fcitx5 copyq dunst dex

# 2) 仅 Hyprland 需源码编译（官方 install.sh 会自动装所有 -dev 构建依赖并编译安装）
sudo apt install -y git
git clone --depth 1 --branch v0.56.2 https://github.com/hyprwm/Hyprland.git /tmp/Hyprland
cd /tmp/Hyprland
./install.sh          # 自动 apt 装依赖 + 编译 + 安装（需要 sudo 权限）
cd / && rm -rf /tmp/Hyprland

# 3) GRUB 开启 nvidia-drm.modeset=1（唯一系统级改动，需 sudo，重启生效）
sudo sed -i 's/^\(GRUB_CMDLINE_LINUX=".*\)"/\1 nvidia-drm.modeset=1/' /etc/default/grub
sudo update-grub

# 4) 软链本仓库配置到 ~/.config（install.sh 已做，可重跑）
bash install.sh

# 5) 重启后登录界面选 Hyprland session
sudo reboot
```

> 后续若想要动画壁纸/更花哨锁屏：源码编译 `swww` 与 `hyprlock` 替换 `swaybg`/`swaylock` 即可（改 `set-wallpaper-hypr.sh` 与 `$mainMod+L` 绑定）。
