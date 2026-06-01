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
| `i3lock` | 锁屏渲染 | 必需 |
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

安装脚本会把配置复制到 `${XDG_CONFIG_HOME:-$HOME/.config}`，并把已有配置备份到带时间戳的目录。它不会重启 i3，也不会主动启动桌面服务。

安装后手动重载 i3：

```sh
i3-msg reload
```

## 维护工作流

这套 dotfiles 有两种实用维护方式。

### 方案 1：真实配置优先

日常继续使用真实桌面配置：

```text
~/.config/i3
~/.config/polybar
~/.config/rofi
~/.config/picom
~/.config/dunst
~/.config/kitty
```

当某个版本稳定到可以发布时，再把真实配置同步回这个仓库，检查 diff，然后提交。

在视觉设计还频繁变化时，这是推荐工作流。它能保持当前桌面调试最快、风险最低，同时仓库作为清理后的发布副本存在。

取舍：

- 对当前桌面会话风险最低
- 可以直接在真实环境中快速试验
- 发布前需要有意识地同步一次
- 仓库可能会暂时落后于真实桌面配置

### 方案 2：仓库优先

直接编辑这个仓库：

```text
/home/coisini/i3-beige-dotfiles/config/i3
/home/coisini/i3-beige-dotfiles/config/polybar
/home/coisini/i3-beige-dotfiles/config/rofi
/home/coisini/i3-beige-dotfiles/config/picom
/home/coisini/i3-beige-dotfiles/config/dunst
/home/coisini/i3-beige-dotfiles/config/kitty
```

然后把仓库版本安装到真实桌面：

```sh
./install.sh
i3-msg reload
```

当这套配置稳定以后，这是更适合长期维护的工作流，因为 Git 会成为唯一可信源。

取舍：

- Git 永远是最新状态
- 每次改动都容易 diff、commit、revert
- 改完需要再应用到 `~/.config`
- 有问题的安装可能影响真实桌面，所以安装前应该先检查 diff

### 推荐路径

现在先使用方案 1。等视觉系统和脚本稳定后，再切换到方案 2。

在仓库工作流完全稳定前，不建议把真实配置目录替换成 symlink。symlink 很方便，但路径损坏或 checkout 不完整时，可能影响 i3 启动和恢复。

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

如果你的设备名称不同，可以把这些变量放到 shell profile 或 i3 启动环境里。

## 本地生成文件

这些文件有意不纳入版本控制：

- `config/i3/workspace-output-routing.conf`
- `config/i3/display-layouts.conf`
- `config/kitty/current-bg`

仓库中提供了对应的 `*.example` 示例文件。安装脚本会在首次安装时创建本地副本。

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
```

## 说明

这套配置假设运行在 X11 i3 会话中，不覆盖 Wayland compositor。
