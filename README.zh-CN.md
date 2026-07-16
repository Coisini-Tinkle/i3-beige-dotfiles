# i3 Beige Dotfiles

[English README](README.md)

这是一套围绕米色单色视觉风格构建的轻量 i3 桌面配置。

## 为什么选择 Ubuntu

这套配置的灵感来自 Arch 系系统上常见的高度可定制桌面体验。Arch 很适合折腾和实验，但作为日常使用的桌面系统，它的更新节奏比较快，长期维护成本也更高。

这个仓库的目标是把一套完成度较高的 i3 桌面美化方案落到 Ubuntu 上。Ubuntu 对日常常用软件的支持和维护更稳定，同时仍然保留了足够空间去定制窗口管理器、状态栏、启动器、合成器、终端和通知界面。

它包含以下配置：

- `i3`：窗口管理器、工作区路由、显示器布局脚本
- `polybar`：顶部浮动栏、多显示器工作区指示器
- `rofi`：应用启动器、电源菜单、Wi-Fi 菜单、控制中心
- `picom`：阴影、圆角、外接电源下的模糊效果、电池模式下的轻量效果
- `dunst` / GJS 通知面板：居中的动态通知界面
- `kitty`：终端主题、随机背景图辅助脚本
- GTK 3：匹配的字体、光标和主题默认值

如果想先理解这些 app 分别负责什么，可以看：

- [i3 配置说明：这些 app 分别做什么](./config/i3/README.zh-CN.md)

## 应用栈

这套桌面效果由以下应用协同实现：

| 应用 | 在本配置中的作用 | 是否必需 |
| --- | --- | --- |
| `i3` | 窗口管理、gaps、边框、工作区规则、快捷键 | 必需 |
| `polybar` | 顶部浮动栏、时间胶囊、工作区圆点、系统模块、托盘 | 必需 |
| `picom` | 阴影、圆角、透明度、模糊、淡入淡出动画 | 必需 |
| `rofi` | 应用启动器、电源菜单、Wi-Fi 菜单、控制中心 UI | 必需 |
| `kitty` | 主题终端、下拉终端、随机背景图 | 必需 |
| `feh` | 设置桌面壁纸 | 必需 |
| `gjs` | 自定义通知 daemon 和下拉通知面板 | 必需 |
| `dunst` | 备用/参考通知配置；启动时会被 GJS daemon 替换 | 可选 |
| `i3lock` / `i3lock-color` | 锁屏渲染；`i3lock-color` 支持放大圆环指示器 | 必需 |
| `xss-lock` | 将休眠/睡眠锁屏接入 i3lock | 推荐 |
| `jq` | 解析 i3 workspace/output JSON，用于路由和 polybar 指示器 | 必需 |
| `xrandr` | 显示器检测和布局切换 | 必需 |
| `imagemagick` | 通过 `convert` 生成锁屏图片尺寸 | 必需 |
| `NetworkManager` / `nmcli` / `nm-applet` | Wi-Fi 菜单和网络托盘 | 推荐 |
| `blueman` | 蓝牙托盘和控制中心状态 | 推荐 |
| `pasystray` | 音频托盘 | 推荐 |
| `power-profiles-daemon` | polybar 电源模式模块 | 推荐 |
| `copyq` | 剪贴板 daemon 和浮动剪贴板窗口规则 | 可选 |
| `flameshot` | 截图快捷键 | 可选 |
| `brightnessctl` | 亮度快捷键 | 可选 |
| `fcitx5` | 输入法启动 | 可选 |
| `dex` | 在 i3 中加载 XDG autostart | 可选 |

## 预览

这套主题是浅米色桌面，搭配黑色墨线感强调色、浮动 polybar 胶囊、圆角窗口、rofi 菜单，以及以键盘操作为核心的 i3/kitty 工作流。

## 安装

克隆仓库后运行：

```sh
./install.sh
```

安装脚本会在 `${XDG_CONFIG_HOME:-$HOME/.config}` 下创建指向仓库的符号链接：

```
~/.config/i3      → repo/config/i3
~/.config/polybar → repo/config/polybar
~/.config/kitty   → repo/config/kitty
... (rofi, picom, dunst, gtk-3.0, systemd/user)
```

已有的配置目录会在创建符号链接前备份到带时间戳的目录。安装是**幂等**的：重复运行会跳过已经指向正确路径的条目。安装后重载 i3：

```sh
i3-msg reload
```

## 维护工作流

使用符号链接后，**编辑 `~/.config/` 和编辑仓库是同一个操作**——它们共享同一个 inode，不需要额外的"同步"步骤。每次修改都会自动反映到 Git 中。

```sh
# 两个路径指向同一个文件，改哪里都行：
vim ~/.config/i3/config
vim ~/i3-beige-dotfiles/config/i3/config

# 检查、提交、推送：
cd ~/i3-beige-dotfiles
git diff
git commit -m "i3: 调整窗口间距"
git push
```

**新机器部署** 只需 `git clone && ./install.sh`。安装脚本会检测已有配置，备份后再创建符号链接。

**各机器独立的本地配置**（`workspace-output-routing.conf`、`display-layouts.conf`、`current-bg`）已加入 `.gitignore`。安装脚本优先从备份恢复，没有备份时才使用 `*.example` 模板。这些文件通过符号链接存在于仓库工作树中，但永远不会被提交，每台机器保持各自的版本。

## 依赖

核心依赖：

- `i3-wm`
- `polybar`
- `rofi`
- `picom`
- `kitty`
- `feh`
- `i3lock`
- `xss-lock`
- `jq`
- `xrandr`
- `gjs`
- `imagemagick`
- `systemd` 用户管理器
- `udevadm`

配置中已经接入、但属于可选增强的组件：

- `dex`
- `fcitx5`
- `copyq`
- `flameshot`
- `brightnessctl`
- `networkmanager`
- `nm-applet`
- `blueman`
- `pasystray`
- `power-profiles-daemon`

## 硬件名称覆盖

部分模块带有机器相关的默认值，但可以不改文件，通过环境变量覆盖：

```sh
export WLAN_INTERFACE=wlan0
export BATTERY=BAT0
export ADAPTER=AC
export PICOM_POWER_PATH=/sys/class/power_supply/AC/online
```

Polybar 相关变量可以放到 shell profile 或 i3 启动环境里。`PICOM_POWER_PATH` 应写入 systemd 用户环境，例如：

```sh
systemctl --user set-environment PICOM_POWER_PATH=/sys/class/power_supply/AC/online
```

未设置覆盖值时，Picom 会自动寻找第一个可用的电源 `online` 文件。

## 本地生成文件

这些文件有意不纳入版本控制（每台机器独立配置）：

- `config/i3/workspace-output-routing.conf`
- `config/i3/display-layouts.conf`
- `config/kitty/current-bg`

仓库中提供了对应的 `*.example` 示例文件。首次安装时从示例创建，重新安装时优先从备份目录恢复之前的版本。

## 目录结构

```text
config/
  dunst/
  gtk-3.0/
  i3/
  kitty/
  picom/
  polybar/
  rofi/
  systemd/user/
```

## 说明

这套配置假设运行在 X11 i3 会话中，不覆盖 Wayland compositor。

诊断记录：[Picom 生命周期与 Polybar 宽度](doc/2026-06-04/picom-polybar-lifecycle-width-diagnosis.html)。
