# i3 配置说明：这些 app 分别做什么

这份说明不是安装教程，而是帮助理解这套桌面环境的组成。目标是：以后看到 `i3`、`polybar`、`rofi`、`picom`、`kitty`、`gjs` 这些名字时，能知道它们大概负责哪一块，出问题时该先看哪里。

## 一句话理解

这套桌面不是一个大程序，而是一组小程序拼起来的：

```text
i3 负责窗口和启动
polybar 负责顶部状态栏
picom 负责阴影、圆角、透明、模糊
rofi 负责弹出的菜单
kitty 负责终端
feh 负责壁纸
gjs 负责自定义通知
一些脚本负责把它们串起来
```

`i3` 是总入口。登录 i3 会话后，它读取 `config/i3/config`，然后启动其他程序。

## 核心组件

| app | 作用 | 如果它坏了会看到什么 |
| --- | --- | --- |
| `i3` | 窗口管理器，决定窗口怎么平铺、浮动、切工作区、快捷键怎么响应 | 窗口布局、快捷键、工作区都不正常 |
| `polybar` | 顶部状态栏，显示时间、工作区圆点、CPU、内存、电池、Wi-Fi、托盘 | 顶部栏消失，时间/状态/工作区指示不见 |
| `picom` | 合成器，负责窗口阴影、圆角、透明度、模糊、动画 | 窗口变生硬，没有阴影/圆角/模糊 |
| `rofi` | 弹出式 UI，负责应用启动器、电源菜单、Wi-Fi 菜单、控制中心 | `Alt+Space`、电源菜单、Wi-Fi 菜单打不开 |
| `kitty` | 终端，包含普通终端和下拉终端 | `Super+Enter` 或下拉终端打不开 |
| `feh` | 设置壁纸 | 壁纸没有设置，背景不对 |
| `gjs` | 运行 JavaScript 桌面小程序，这里用于自定义通知面板 | 通知不弹出，或动态通知面板不工作 |

## i3 在这里做什么

`config/i3/config` 是入口文件，它主要做几件事：

- 设置快捷键，例如打开终端、启动 rofi、锁屏、截图、切工作区
- 设置窗口规则，例如 rofi 无边框、下拉终端浮动、通知面板浮动
- 设置颜色、边框、gaps、字体
- 启动视觉相关服务，例如 `feh`、`picom`、`polybar`
- 启动辅助服务，例如输入法、网络托盘、蓝牙托盘、音频托盘、通知 daemon

可以把 i3 理解成这套桌面的“调度器”。

## 启动链路

登录 i3 后，配置大致按这个顺序工作：

```text
i3 读取 config
  -> include workspace-output-routing.conf
  -> 启动 dex autostart
  -> 启动 xss-lock + i3lock
  -> 启动 fcitx5 输入法
  -> feh 设置壁纸
  -> picom-launcher.sh 启动 picom
  -> 启动 copyq
  -> display-hotplug-watch.sh 监听显示器热插拔
  -> workspace-routing.sh 生成工作区输出规则
  -> polybar/launch.sh 启动顶部栏
  -> 启动 nm-applet / pasystray / blueman-applet
  -> hide_todesk_overlays.py 处理 ToDesk 浮窗
  -> notification-daemon.js 接管通知
```

不是每一项都绝对必须。核心视觉效果主要依赖 `i3 + polybar + picom + rofi + kitty + feh + gjs`。

## 状态栏相关

`polybar` 由这里启动：

```text
~/.config/polybar/launch.sh
```

它读取：

```text
~/.config/polybar/config.ini
```

当前顶部栏里主要有这些模块：

- `menu`：左侧图标，点击打开 rofi 应用启动器
- `workspaces`：工作区圆点，来自 `polybar/scripts/i3-workspaces.sh`
- `date`：中间时间胶囊
- `memory`：内存
- `cpu`：CPU
- `battery`：电池
- `power-profile`：电源模式
- `wlan`：Wi-Fi
- `tray`：系统托盘

如果顶部栏没有出现，优先看：

```text
~/.config/polybar/launch.sh
~/.config/polybar/config.ini
/tmp/polybar-main.log
```

## 视觉效果相关

`picom` 负责窗口效果。这里不是直接启动 `picom`，而是启动：

```text
~/.config/i3/picom-launcher.sh
```

这个脚本会根据电源状态选择配置：

```text
~/.config/picom/picom-full.conf   # 外接电源，效果更完整
~/.config/picom/picom-lite.conf   # 电池模式，效果更轻量
```

如果窗口没有阴影、圆角、模糊，优先看：

```text
picom 是否运行
/tmp/picom-launcher.log
~/.config/picom/picom-full.conf
~/.config/picom/picom-lite.conf
```

## 菜单相关

`rofi` 负责所有弹出式菜单：

- `rofi -show drun`：应用启动器
- `rofi-power-menu.sh`：关机、重启、锁屏菜单
- `rofi-wifi-menu.sh`：Wi-Fi 菜单
- `rofi-control-center.sh`：控制中心

样式文件在：

```text
~/.config/rofi/config.rasi
~/.config/rofi/control-center.rasi
```

如果菜单能打开但样式不对，通常看 `.rasi` 文件。如果菜单打不开，先看对应 `.sh` 脚本。

## 通知相关

这套配置没有主要依赖 `dunst` 显示通知，而是启动了：

```text
~/.config/i3/notification-daemon.js
```

它会占用 `org.freedesktop.Notifications` 这个 DBus 名字，然后每条通知调用：

```text
~/.config/i3/notification-drop-panel.js
```

也就是说：

```text
notification-daemon.js 负责接收通知
notification-drop-panel.js 负责显示通知界面
gjs 负责运行这两个 JS 文件
```

`dunst` 配置仍然保留，但当前 i3 启动时会先杀掉 `dunst`，再启动自定义 GJS 通知 daemon。

如果通知不工作，优先看：

```text
/tmp/notification-daemon.log
~/.config/i3/notification-daemon.js
~/.config/i3/notification-drop-panel.js
```

## 终端相关

默认终端不是直接写 `kitty`，而是：

```text
~/.config/kitty/kitty-random.sh
```

它会先调用：

```text
~/.config/kitty/random-bg.sh
```

然后再启动 `kitty`。这样每次打开终端时可以切换背景图。

下拉终端由这个脚本控制：

```text
~/.config/i3/dropdown-terminal.sh
```

i3 里给下拉终端设置了浮动、固定尺寸和居中规则。

## 显示器和工作区相关

这部分由几个脚本配合：

| 文件 | 作用 |
| --- | --- |
| `display-layout.sh` | 手动切换外屏在左/右/上、仅外屏、镜像、仅内屏 |
| `display-hotplug-watch.sh` | 监听显示器插拔，自动恢复布局 |
| `workspace-routing.sh` | 根据当前显示器生成工作区输出规则 |
| `switch-workspace-fixed-output.sh` | 按工作区编号切换，并把工作区放到预期屏幕 |
| `workspace-output-routing.conf` | 运行时生成的 i3 workspace output 规则 |
| `display-layouts.conf` | 运行时保存的显示器布局偏好 |

这两个文件是本机状态，不应该提交到 Git：

```text
workspace-output-routing.conf
display-layouts.conf
```

仓库里只保留 `*.example` 作为模板。

如果工作区跑错屏幕，优先看：

```text
~/.config/i3/workspace-routing.sh
~/.config/i3/workspace-output-routing.conf
/tmp/workspace-routing.log
```

如果插拔显示器后布局不对，优先看：

```text
~/.config/i3/display-hotplug-watch.sh
~/.config/i3/display-layout.sh
/tmp/display-hotplug-watch.log
```

## 托盘和系统辅助

这些不是视觉核心，但会让桌面更完整：

| app | 作用 |
| --- | --- |
| `nm-applet` | 网络托盘图标 |
| `blueman-applet` | 蓝牙托盘图标 |
| `pasystray` | 音频托盘图标 |
| `copyq` | 剪贴板 |
| `flameshot` | 截图 |
| `brightnessctl` | 亮度快捷键 |
| `fcitx5` | 输入法 |
| `dex` | 加载 XDG autostart 程序 |

这些缺失时，桌面主体仍然能跑，但对应功能会不可用。

## 快速排查表

| 现象 | 先看哪里 |
| --- | --- |
| 顶部栏没有了 | `polybar/launch.sh`、`polybar/config.ini`、`/tmp/polybar-main.log` |
| 窗口没有圆角/阴影 | `picom-launcher.sh`、`picom-full.conf`、`/tmp/picom-launcher.log` |
| 壁纸没设置 | `feh`、`themes/beige/wallpaper.png` |
| rofi 菜单打不开 | `rofi` 是否安装、对应 `rofi-*.sh` |
| 通知不显示 | `notification-daemon.js`、`notification-drop-panel.js`、`/tmp/notification-daemon.log` |
| 终端打不开 | `kitty-random.sh`、`kitty.conf` |
| 下拉终端不对 | `dropdown-terminal.sh`、i3 里的 `kitty-dropdown` 规则 |
| 工作区跑错屏幕 | `workspace-routing.sh`、`workspace-output-routing.conf` |
| 插拔显示器后布局不对 | `display-hotplug-watch.sh`、`display-layout.sh` |
| Wi-Fi 菜单不工作 | `nmcli`、`rofi-wifi-menu.sh` |
| 电源模式不显示 | `powerprofilesctl`、`polybar/scripts/power-profile.sh` |

## 最重要的心智模型

不用一次理解所有东西。先记住：

```text
i3 管窗口和启动
polybar 管顶部栏
picom 管视觉特效
rofi 管弹出菜单
kitty 管终端
gjs 管自定义通知
脚本负责自动化和连接
```

以后排查问题时，先根据“问题属于哪一块”定位到对应 app，再看对应脚本和日志。
