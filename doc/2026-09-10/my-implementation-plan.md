# my Implementation Plan

> 执行方式：本会话内联执行（单文件 Bash 脚本，无需子代理）。

**Goal:** 实现 `bin/my` 并在 `~/.local/bin/my` 可用：临时保持屏幕常亮/不休眠，模拟训练日志，退出（含 `kill -9`）自动恢复。

**Architecture:** 单文件 Bash。主进程解析并保存 `xset` 状态 → 启动 `systemd-inhibit ... sleep infinity` 子进程持有 idle/sleep 抑制 → `setsid` 启动守护子进程 → `xset s off; xset -dpms` → 日志循环。`trap` 恢复；守护用 `setsid` + 忽略信号，在主进程异常死亡时兜底恢复并杀掉抑制进程。

**Tech Stack:** Bash、xset、systemd-inhibit、setsid、nvidia-smi（可选）、setsid。

## Global Constraints

- 不改 `/etc` 与任何 shell rc；不永久改锁屏/电源配置。
- 不杀 `xss-lock` 或无关进程。
- 安装位置 `~/.local/bin/my`（仓库源 `bin/my`，symlink 部署）。
- `kill -9` 后不得残留「永不锁屏」。
- 日志真实时间戳、1~4s 随机、模板多样、CPU/GPU 近零。
- 默认不拦截合盖；`MY_BLOCK_LID=1` 可选。

---

### Task 1: 主脚本骨架与 xset 状态捕获/恢复

**Files:**

- Create: `bin/my`

- [ ] 写参数分发（`--guardian` 隐藏分支）、`capture_xset`、`restore_xset`、`disable_xset`。
- [ ] 验证：`bash -n bin/my`；手动 source 函数测试 `xset q` 解析。

### Task 2: systemd-inhibit 抑制 + 守护兜底

**Files:**

- Modify: `bin/my`

- [ ] 启动 `systemd-inhibit --what=idle:sleep --mode=block ... sleep infinity` 子进程并记录 PID。
- [ ] `setsid bin/my --guardian <main_pid>` 守护：主死且状态文件仍在 → 杀抑制剂、恢复、清理。
- [ ] `cleanup`（INT/TERM/HUP/EXIT，幂等）恢复并输出两行提示。
- [ ] 验证：正常退出、`kill -TERM`、`kill -9` 三种均恢复，无残留。

### Task 3: 锁屏机制检测（只读）

**Files:**

- Modify: `bin/my`

- [ ] `pgrep -af 'xss-lock|xautolock|i3lock|light-locker|gnome-screensaver'` 打印检测结果，不做修改。

### Task 4: 模拟训练日志

**Files:**

- Modify: `bin/my`

- [ ] 定点小数格式化 `fmt`；状态变量随机游走；模板：rollout / PPO / eval / checkpoint / gpu / mamba / buffer。
- [ ] `date +%H:%M:%S` 真实时间戳；`sleep 1..4`。
- [ ] GPU：`nvidia-smi` 存在时每 ≥45s 读一次 util/mem/temp 缓存混入，否则跳过。
- [ ] 验证：跑 30s 观察多样性与连贯性；`ps`/`top` 观察 CPU 近零。

### Task 5: 安装与端到端验证

**Files:**

- Create: `~/.local/bin/my`（symlink → `bin/my`）

- [ ] `ln -sfn <repo>/bin/my ~/.local/bin/my`；`chmod +x`。
- [ ] 记录启动前 `xset q`；运行 `my`；确认 saver/DPMS 状态变化。
- [ ] Ctrl+C → 两行提示 + `xset q` 与启动前逐项一致。
- [ ] `kill -TERM` / `kill -9` 各验证一次；确认 `xss-lock` 存活、无残留守护/抑制进程与状态文件。
- [ ] `shellcheck` 缺失则说明。

---

## Self-Review

- 覆盖需求 1~14：命令/安装、禁用项、systemd-inhibit、锁屏检测、不改配置、trap、日志、GPU、Ctrl+C 输出、检测命令、验证——均有对应 Task。
- 无占位符；函数命名前后一致（`capture_xset` / `restore_xset` / `disable_xset` / `run_guardian` / `cleanup`）。
