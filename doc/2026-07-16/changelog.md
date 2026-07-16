# 2026-07-16 更新日志

## install.sh：rsync 复制 → 符号链接

`install.sh` 不再把配置**复制**到 `~/.config/`，改为创建**符号链接**：

```
~/.config/i3      → repo/config/i3
~/.config/polybar → repo/config/polybar
~/.config/kitty   → repo/config/kitty
... (rofi, picom, dunst, gtk-3.0, systemd/user)
```

效果：编辑 `~/.config/` 就是在编辑 repo，git 自动追踪，不再出现"两份拷贝忘同步"的问题。

`install.sh` 是幂等的：重复运行跳过已指向正确位置的条目。gitignored 的本地文件（`routing.conf`、`layout.conf`）优先从备份恢复，没有备份才用 `.example` 模板。

## 焦点窗口可见性增强

三管齐下解决"分不清哪个窗口有焦点"：

| 维度 | Before | After |
|------|--------|-------|
| 边框宽度 | 2px | **3px** |
| Focused 边框颜色 | #1a1a1a (ink) | **#4f8a82 (cyan)** |
| Unfocused 边框 | #c9bfb4 (可见) | #dcd3ca (跟背景融为一体) |
| Unfocused 透明度 | 1.0 (不透明) | **0.5 (50% 透明)** |
| 毛玻璃 (blur) | 开 | **关** |

配置位置：
- i3 边框：`config/i3/config`（client 颜色放在 theme include **之后**以确保覆盖）
- picom 透明/blur：`config/picom/picom-full.conf` + `config/picom/picom-lite.conf`

## config/i3/themes 重构

把主题目录精简为"一个主题 = `theme.conf` + 壁纸"：

```
themes/
├── beige/                  ← theme.conf + wallpaper.png + wallpaper2.png
├── wallpaper2/             ← theme.conf + wallpaper.png → ../beige/wallpaper2.png
├── current/                ← 运行时生成（gitignored，不变）
└── _refs/                  ← 非功能性配色参考（polybar/btop/cava/fastfetch）
```

搬走了之前混在 `beige/` 里的 polybar 配置副本、btop/cava/fastfetch 配色参考、空 `rofi/` 目录、死掉 `wallpaper-current.png` 软链接。主题引擎只读 `theme.conf`，其他 clutter 全部移走。

## config/i3 目录重构

30+ 文件平铺 → 按功能分到子目录：

```
config/i3/
├── config                  ← i3 主配置
├── theme-switcher.sh       ← 主题引擎
├── lock.sh                 ← 锁屏
├── dropdown-terminal.sh    ← 下拉终端
├── tray.sh                 ← 托盘启动
├── display/                ← 显示器 & 工作区路由 (8 files)
├── rofi/                   ← rofi 菜单 (3 files)
├── panels/                 ← GJS 面板 (6 files)
├── notify/                 ← 通知 daemon + 面板 (3 files)
├── picom/                  ← 合成器启动器 + 电源监视 (2 files)
├── themes/                 ← 主题定义
└── test/                   ← 冒烟测试 (3 files)
```

**删除的死代码**：
- `wallpaper-theme.sh` — 一行 wrapper，未被引用
- `workspace-buttons.sh` — 无任何引用
- `switch-workspace-current-output.sh` — 无任何引用
- `hide_todesk_overlays.py` — ToDesk 已移除

所有引用路径已同步更新：i3 config（~20 处）、polybar config、systemd service、各脚本间的相互调用。
