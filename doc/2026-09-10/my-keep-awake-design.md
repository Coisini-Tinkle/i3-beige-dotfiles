# my — 临时保持屏幕常亮并模拟训练日志

日期：2026-09-10
目标平台：Ubuntu 22.04 + i3 (X11)

## 1. 目标

`my` 是一个放在 `~/.local/bin/my` 的可执行 Bash 工具，用于用户暂时离开时：

- 屏幕保持亮起，不因 idle 而 blank / 熄屏 / 锁屏 / 挂起；
- 当前终端持续输出看起来像正常深度学习 / 强化学习实验的日志；
- 退出（Ctrl+C / SIGTERM / 正常退出 / 异常死亡）后**自动恢复**启动前的显示与电源状态；
- 不永久修改任何配置，不触碰 `/etc`，不造成「永不锁屏」隐患。

## 2. 实测环境（2026-09-10）

| 项目                               | 结果                                                                                |
| ---------------------------------- | ----------------------------------------------------------------------------------- |
| `XDG_SESSION_TYPE`                 | `x11`                                                                               |
| `XDG_CURRENT_DESKTOP`              | `i3`                                                                                |
| `DISPLAY`                          | `:1`                                                                                |
| 锁屏链路                           | `xss-lock` (PID 3061) → `bash ~/.config/i3/lock.sh` → `i3lock-color` / `i3lock`     |
| 其他锁屏器                         | `xautolock` 无、`light-locker` 无、`gnome-screensaver`/`gsd-power` 无               |
| DBus `org.freedesktop.ScreenSaver` | 无 owner（DBus 抑制在裸 i3 下无效）                                                 |
| `xset q`                           | saver `timeout=600 cycle=600`，`prefer blanking=yes`；DPMS `Enabled`，`600/600/600` |
| `systemd-inhibit`                  | 可用                                                                                |
| logind                             | `IdleAction` 默认 ignore；`HandleLidSwitch=suspend`                                 |
| `nvidia-smi`                       | 可用（GPU0，实测可读到数据）                                                        |
| `gsettings`                        | 可用，但 GNOME 未控制 i3 会话（`idle-delay=0`）                                     |
| `~/.local/bin`                     | 已在 `PATH`，无需改 shell rc                                                        |
| 缺失工具                           | `xdotool`、`shellcheck`                                                             |

锁屏守护进程 `xss-lock` 监听 XScreenSaver 事件（idle 触发 active → 调 `lock.sh`），并带
`--transfer-sleep-lock` 在系统 sleep 前抢锁。因此只要使 **X saver 永不激活** 且 **系统不进入
idle sleep**，`xss-lock` 就不会触发，无需暂停或杀死任何守护进程。

## 3. 方案对比

- **方案 A — `xset s reset` 续命循环（否定）**
  `man xset` 明确：`s reset` 仅「若屏保已激活则取消」，不重置 idle 计时器，不能推迟 blank。
  无 `xdotool` 时又缺少可靠的合成输入手段，故不可靠。

- **方案 B — 临时关闭 X saver + DPMS + systemd-inhibit + 守护兜底（采纳）**
  确定性生效；`trap` 恢复；再用一个忽略信号、`setsid` 脱离进程组的守护子进程，在主进程
  异常死亡（含 `kill -9`、终端被关）时按已记录状态恢复，杜绝「永不锁屏」残留。

- **方案 C — 仅 trap 恢复（不采纳）**
  `kill -9` / 崩溃会残留禁用状态直到重新登录。

## 4. 设计（方案 B）

### 4.1 进程结构

```
终端
 └─ systemd-inhibit --what=idle:sleep --mode=block --why=...  (主进程，持有 inhibitor FD)
     └─ bash my --run                                      (业务：应用 xset + 日志循环 + trap)
         └─ setsid bash my --guardian <main_pid> <state>   (守护：主进程死后兜底恢复)
```

- 外层用 `systemd-inhibit` 包裹：inhibitor 随进程生命周期自动释放，即使 `kill -9` 也不会
  留下 sleep 抑制。
- `--run` 分支：捕获状态 → 起守护 → 应用禁用 → 检测锁屏机制 → 日志循环。
- `--guardian` 分支：`setsid` 脱离进程组并忽略 `INT/TERM/HUP`，轮询主 PID；主 PID 消失且
  未正常清理时按状态文件恢复 `xset`，随后退出（不常驻）。

### 4.2 启动顺序（尽量缩小风险窗口）

1. 解析 `xset q`，把原始值写入 `$XDG_RUNTIME_DIR/my/xset.state`（可 source 的键值）。
2. **先启动守护**（此时状态文件已就绪）。
3. 应用禁用：`xset s off` + `xset -dpms`。
4. 检测并打印当前锁屏机制（只读检测，不修改）。
5. 进入日志循环。

启动后任意时刻主进程死亡，守护都能恢复；正常退出时主进程恢复后主动结束守护。

### 4.3 恢复逻辑

从状态文件读取并执行：

- `xset s blank` / `xset s noblank`（按 `prefer blanking`）
- `timeout>0` → `xset s <timeout> <cycle>`；否则 `xset s off`
- `xset dpms <standby> <suspend> <off>`
- `DPMS is Enabled` → `xset +dpms`，否则 `xset -dpms`

`trap cleanup INT TERM EXIT`；`cleanup` 幂等，输出：

```
[my] restoring display and lock settings...
[my] restored.
```

### 4.4 锁屏机制检测（只读）

检测 `xss-lock`、`xautolock`、`i3lock`、`i3lock-fancy`、`light-locker`、
`gnome-screensaver`/`gsd-power` 等，打印结果用于日志。**本设计不暂停任何守护进程**，
因为关闭 X saver + DPMS 后依赖 XScreenSaver 的锁屏器不会触发；若未来检测到依赖
DBus `org.freedesktop.ScreenSaver` 的锁屏器，则额外尝试 Inhibit（失败静默）。

### 4.5 安全边界

- 不改 `/etc`，不写 shell rc，不永久改任何锁屏/电源配置。
- 不杀 `xss-lock` 或任何无关进程。
- `kill -9` / 崩溃由守护兜底恢复；守护自身仅存活于 my 会话期间。
- 默认**不拦截合盖**（避免装包过热）；`MY_BLOCK_LID=1` 时尝试追加
  `handle-lid-switch`（若权限不允许则回退到 `idle:sleep`）。
- 退出后 `xset q` 必须与启动前一致（数值对比验证）。

### 4.6 日志生成

- 纯 Bash，无外部依赖（GPU 检测除外）。
- 真实时间戳：`date +%H:%M:%S`。
- 随机间隔 1~4 秒。
- 使用 `$RANDOM` + 定点整数（scaled）实现小数格式化，CPU 占用接近零。
- 随机游走保证数值连贯：reward 缓慢上升、loss 缓慢下降、fps 波动、rollout 累加满 512
  重置、checkpoint 每 N 次 update、eval 间歇出现。
- 模板混含：`rollout` / `PPO update` / `eval` / `checkpoint saved` / `gpu` / `mamba` /
  `buffer`，避免重复同一模板。
- **不实际训练**。

### 4.7 GPU 信息

- 仅当 `nvidia-smi` 存在时启用。
- 每 ≥30~60 秒真实读取一次 `utilization.gpu / memory.used / memory.total / temperature.gpu`，
  缓存后混入 `gpu` 日志行；不做高频轮询。
- 无 NVIDIA GPU 或命令失败时静默跳过。

## 5. 交付物

- 新增 `bin/my`（仓库源文件），按 `install.sh` 约定 symlink 到 `~/.local/bin/my`。
- 本文档。
- 不自动 `git commit`（遵循「未要求不提交」）。

## 6. 验证计划

1. `shellcheck bin/my`（若存在；当前缺失则说明）。
2. 启动 `my`，确认日志输出与 `xset q` 变为 saver off / DPMS disabled。
3. Ctrl+C → 出现 `[my] restoring...` / `[my] restored.`，`xset q` 与启动前逐项一致。
4. `kill -TERM` 主进程 → 同样恢复。
5. `kill -9` 主进程 → 守护在 1~2 秒内恢复；无残留进程、无残留状态。
6. 确认 `xss-lock` 仍存活，未误杀。
7. 观测运行期 CPU 占用接近零。
