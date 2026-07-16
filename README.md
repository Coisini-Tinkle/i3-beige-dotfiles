# i3 Beige Dotfiles

[中文说明](README.zh-CN.md)

A compact i3 desktop setup built around a beige monochrome visual style.

## Why Ubuntu

This setup is inspired by the highly customizable desktop experience that is common on Arch-based systems. Arch is excellent for experimentation, but for a daily desktop it can move faster than some workflows need, which increases maintenance cost.

The goal of this repository is to bring a polished i3 desktop experience to Ubuntu instead. Ubuntu tends to provide a steadier base for the everyday applications used in this workflow, while still leaving enough room to customize the window manager, bar, launcher, compositor, terminal, and notification surface.

It includes coordinated configs for:

- `i3`: window manager, workspace routing, display layout scripts
- `polybar`: floating top bars, per-monitor workspace indicators
- `rofi`: launcher, power menu, Wi-Fi menu, control center
- `picom`: shadows, rounded corners, blur on AC power, lighter battery mode
- `dunst` / GJS notification panel: centered dynamic notification surface
- `kitty`: terminal theme, random background image helper
- GTK 3: matching font/cursor/theme defaults

## Application Stack

These are the apps that work together to create the full desktop effect:

| App | Role in this setup | Required |
| --- | --- | --- |
| `i3` | Window manager, gaps, borders, workspace rules, keybindings | Yes |
| `polybar` | Floating top bar, date island, workspace dots, system modules, tray | Yes |
| `picom` | Shadows, rounded corners, opacity, blur, fade animations | Yes |
| `rofi` | App launcher, power menu, Wi-Fi menu, control center UI | Yes |
| `kitty` | Themed terminal, dropdown terminal, random background image | Yes |
| `feh` | Wallpaper setter | Yes |
| `gjs` | Custom notification daemon and drop-down notification panel | Yes |
| `dunst` | Fallback/reference notification config; replaced at startup by the GJS daemon | Optional |
| `i3lock` / `i3lock-color` | Lock screen renderer; `i3lock-color` enables larger ring indicators | Yes |
| `xss-lock` | Hooks suspend/sleep locking into i3lock | Recommended |
| `jq` | Parses i3 workspace/output JSON for routing and polybar indicators | Yes |
| `xrandr` | Display detection and layout switching | Yes |
| `imagemagick` | Generates the lock-screen image size via `convert` | Yes |
| `NetworkManager` / `nmcli` / `nm-applet` | Wi-Fi menu and tray network applet | Recommended |
| `blueman` | Bluetooth tray applet and control center status | Recommended |
| `pasystray` | Audio tray applet | Recommended |
| `power-profiles-daemon` | Polybar power profile module | Recommended |
| `copyq` | Clipboard daemon and floating clipboard window rule | Optional |
| `flameshot` | Screenshot keybindings | Optional |
| `brightnessctl` | Brightness keybindings | Optional |
| `fcitx5` | Input method startup | Optional |
| `dex` | XDG autostart support inside i3 | Optional |

## Preview

The theme is a light beige desktop with black ink accents, floating polybar capsules, rounded windows, rofi menus, and an i3/kitty workflow tuned for keyboard use.

## Install

Clone the repo and run:

```sh
./install.sh
```

The installer creates symlinks from `${XDG_CONFIG_HOME:-$HOME/.config}` into the repo:

```
~/.config/i3      → repo/config/i3
~/.config/polybar → repo/config/polybar
~/.config/kitty   → repo/config/kitty
... (rofi, picom, dunst, gtk-3.0, systemd/user)
```

Existing config directories are backed up to a timestamped directory before symlinking. The install is **idempotent**: re-running it skips entries that already point to the correct repo paths. After installation, reload i3:

```sh
i3-msg reload
```

## Maintenance Workflow

With symlinks in place, **editing `~/.config/` and editing the repo are the same operation** — they share the same inode. There is no "sync step." Every config change is automatically visible to Git.

```sh
# Edit anywhere — both paths resolve to the same file:
vim ~/.config/i3/config
vim ~/i3-beige-dotfiles/config/i3/config

# Review, commit, push as usual:
cd ~/i3-beige-dotfiles
git diff
git commit -m "i3: tweak workspace gaps"
git push
```

**New machine setup** is just `git clone && ./install.sh`. The installer detects existing configs, backs them up, and symlinks the repo versions in place.

**Per-machine local configs** (`workspace-output-routing.conf`, `display-layouts.conf`, `current-bg`) are gitignored. The installer restores them from backup when available, or falls back to the `*.example` templates. These files live in the repo working tree (through the symlink) but are never committed, so each machine keeps its own.

## Dependencies

Core:

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
- `systemd` user manager
- `udevadm`

Optional but wired into the config:

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

## Hardware Overrides

Some modules have machine-specific defaults, but can be overridden without editing files:

```sh
export WLAN_INTERFACE=wlan0
export BATTERY=BAT0
export ADAPTER=AC
export PICOM_POWER_PATH=/sys/class/power_supply/AC/online
```

Put the Polybar overrides in your shell profile or i3 startup environment. For `PICOM_POWER_PATH`, use the systemd user environment, for example:

```sh
systemctl --user set-environment PICOM_POWER_PATH=/sys/class/power_supply/AC/online
```

Picom automatically detects the first available power-supply `online` file when no override is set.

## Generated Local Files

These files are intentionally not versioned (per-machine state):

- `config/i3/workspace-output-routing.conf`
- `config/i3/display-layouts.conf`
- `config/kitty/current-bg`

Examples are included as `*.example`. On first install, the script creates them from the examples. On re-install, it restores the previous versions from the backup directory when available.

## Structure

```text
config/
├── i3/
│   ├── config                  ← main i3 config
│   ├── theme-switcher.sh       ← theme engine
│   └── themes/
│       ├── beige/              ← "Beige Mono" theme
│       │   ├── theme.conf      ← color palette (the only required file)
│       │   ├── wallpaper.png   ← theme wallpaper
│       │   └── wallpaper2.png  ← shared wallpaper (used by other themes)
│       ├── wallpaper2/         ← "Ink Portrait" theme
│       │   ├── theme.conf
│       │   └── wallpaper.png → ../beige/wallpaper2.png
│       ├── current/            ← runtime output (gitignored)
│       │   ├── i3-colors.conf  ← generated: i3 client colors
│       │   ├── kitty.conf      ← generated: kitty terminal colors
│       │   ├── theme.conf      ← copy of active theme.conf
│       │   └── wallpaper.png   ← copy of active wallpaper
│       └── _refs/              ← color reference for other apps (manual)
│           ├── polybar/
│           ├── btop/
│           ├── cava/
│           └── fastfetch/
├── polybar/
├── kitty/
├── picom/
├── rofi/
├── dunst/
├── gtk-3.0/
└── systemd/user/
```

### How themes work

A theme is just a color palette (`theme.conf`) + a wallpaper image:

```sh
# theme.conf example
THEME_LABEL="Beige Mono"
BAR_BG="#dcd3ca"
INK="#1a1a1a"
ACCENT="#ca7081"
# ... ~20 color variables
```

`theme-switcher.sh apply <theme>` reads the palette and generates:
- `i3-colors.conf` — i3 window border / title bar colors
- `kitty.conf` — terminal background, foreground, cursor colors
- polybar color block — inline replacement in `config/polybar/config.ini`
- CSS skins for control center / music panel

All generated artifacts land in `themes/current/`, which is **gitignored** — it's rebuilt from `theme.conf` on every theme switch. i3 and kitty include from `current/`, so switching themes is instant.

Available themes: `beige` (Beige Mono, warm pink accent) and `wallpaper2` (Ink Portrait, purple accent). Switch with `theme-switcher.sh apply <name>` or `theme-switcher.sh menu` (rofi picker).

## Notes

This setup assumes an X11 i3 session. Wayland compositors are out of scope.

Diagnosis note: [Picom lifecycle and Polybar width](doc/2026-06-04/picom-polybar-lifecycle-width-diagnosis.html).
