# freeze —— 卡死安全重启

笔记本卡死时，在黑屏 TTY（`Ctrl+Alt+F3`）里登录后输入 `freeze`，脚本会自动：

1. **保存数据**（`sync`）—— 把内存里未落盘的数据刷到磁盘，防止最近的工作丢失
2. **干净重启**（`systemctl reboot`，限时 5 秒）—— systemd 正常关停服务后重启
3. **备用硬重启**（仅当 systemd 卡死没反应）—— 先把根文件系统设为只读防写坏，再走内核级 `SysRq-b` 直接重启

每一步都比"强制断电"安全。要求 `kernel.sysrq` 掩码含 128（Ubuntu 默认 `176` 已含）。

## 组成

| 文件 | 用途 | 安装位置 |
| --- | --- | --- |
| `../bin/reboot-safe` | 脚本本体 | 符号链接到 `~/.local/bin/reboot-safe`（`install.sh` 自动做） |
| `zshrc-alias.txt` | 别名 `freeze` 定义 | 追加到 `~/.zshrc`（手动） |
| `sudoers` | 免密码 sudo 规则 | `/etc/sudoers.d/reboot-safe`（手动，需 root） |

## 在一台新机器上安装

```bash
# 1. 脚本符号链接（install.sh 会处理；也可手动）：
mkdir -p ~/.local/bin
ln -sfn "$PWD/bin/reboot-safe" ~/.local/bin/reboot-safe

# 2. 追加别名到 ~/.zshrc：
cat config/freeze/zshrc-alias.txt >> ~/.zshrc

# 3. 免密码 sudo（把 USER 换成实际用户名）：
sed 's/USER/'"$USER"'/g' config/freeze/sudoers | sudo tee /etc/sudoers.d/reboot-safe
sudo chmod 440 /etc/sudoers.d/reboot-safe
sudo visudo -c
```

## 验证

```bash
freeze --dry    # 演练模式：打印会做什么，不会真重启
```

卡死时：`Ctrl+Alt+F3` → 登录 → `freeze` → 回车。
