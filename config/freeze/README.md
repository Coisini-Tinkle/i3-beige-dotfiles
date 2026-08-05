# freeze —— 卡死安全重启 + 重启后复盘通知

笔记本卡死时，在黑屏 TTY（`Ctrl+Alt+F3`）里登录后输入 `freeze`，脚本会自动：

1. **采集诊断信息** —— 把本开机错误日志、显卡/内核关键字、picom 日志存到 `~/.cache/freeze/crash-context.txt`（存磁盘，重启不丢）
2. **保存数据**（`sync`）—— 把内存里未落盘的数据刷到磁盘，防止最近的工作丢失
3. **干净重启**（`systemctl reboot`，限时 5 秒）—— systemd 正常关停服务后重启
4. **备用硬重启**（仅当 systemd 卡死没反应）—— 先把根文件系统设为只读防写坏，再走内核级 `SysRq-b` 直接重启

**重启后**：`freeze-report` 检测到 `crash-context.txt` 存在 → 自动弹桌面通知（dunst）告诉你"上次是 freeze 重启的"，并附诊断报告；完整报告存 `~/.cache/freeze/last-report.txt`。

每一步都比"强制断电"安全。要求 `kernel.sysrq` 掩码含 128（Ubuntu 默认 `176` 已含）。

## 组成

| 文件 | 用途 | 安装位置 |
| --- | --- | --- |
| `../bin/reboot-safe` | 重启脚本本体（采集 + 保存 + 重启） | 符号链接到 `~/.local/bin/reboot-safe`（`install.sh` 自动做） |
| `../bin/freeze-report` | 重启后读报告 + 弹桌面通知 | 符号链接到 `~/.local/bin/freeze-report`（`install.sh` 自动做） |
| `zshrc-alias.txt` | 别名 `freeze` 定义 | 追加到 `~/.zshrc`（手动） |
| `sudoers` | 免密码 sudo 规则 | `/etc/sudoers.d/reboot-safe`（手动，需 root） |

`freeze-report` 由 i3 config 里的 `exec_always` 自动运行，无需手动配置 alias。

## 在一台新机器上安装

```bash
# 1. 脚本符号链接（install.sh 会自动做；也可手动）：
mkdir -p ~/.local/bin
ln -sfn "$PWD/bin/reboot-safe"  ~/.local/bin/reboot-safe
ln -sfn "$PWD/bin/freeze-report" ~/.local/bin/freeze-report

# 2. 追加别名到 ~/.zshrc：
cat config/freeze/zshrc-alias.txt >> ~/.zshrc

# 3. 免密码 sudo（把 USER 换成实际用户名）：
sed 's/USER/'"$USER"'/g' config/freeze/sudoers | sudo tee /etc/sudoers.d/reboot-safe
sudo chmod 440 /etc/sudoers.d/reboot-safe
sudo visudo -c

# 4. i3 config 加一行（让重启后自动弹通知）：
#    exec_always --no-startup-id /home/USER/.local/bin/freeze-report
```

## 验证

```bash
freeze --dry    # 演练模式：打印会做什么，不会真重启

# 模拟一次 freeze 重启后的复盘通知：
mkdir -p ~/.cache/freeze
printf '===== 测试：freeze 安全重启诊断信息 =====\ntime: %s\nuptime: %s\n' "$(date)" "$(uptime -p)" > ~/.cache/freeze/crash-context.txt
~/.local/bin/freeze-report          # 应弹出桌面通知
ls ~/.cache/freeze/crash-context.txt  # 应已不存在（通知弹完自动清理）
```

卡死时：`Ctrl+Alt+F3` → 登录 → `freeze` → 回车；重启登录后桌面会弹出复盘通知。
