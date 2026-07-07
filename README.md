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

The installer copies configs and user systemd units into `${XDG_CONFIG_HOME:-$HOME/.config}`, backs up existing app configs into a timestamped directory, and reloads the user systemd manager. It does not restart i3 or launch desktop services.

After installation, reload i3:

```sh
i3-msg reload
```

## Maintenance Workflow

There are two practical ways to maintain these dotfiles.

### Option 1: Live Config First

Use the real desktop configs day to day:

```text
~/.config/i3
~/.config/polybar
~/.config/rofi
~/.config/picom
~/.config/dunst
~/.config/kitty
```

When a version is stable enough to publish, sync the live configs back into this repo, review the diff, then commit.

This is the recommended workflow while the visual design is still changing often. It keeps the active desktop workflow fast and low-risk, while the repository remains a cleaned-up publishing copy.

Tradeoffs:

- Lowest risk for the current desktop session
- Easy to experiment directly in the live environment
- Requires a deliberate sync step before publishing
- The repo may lag behind the live desktop until synced

### Option 2: Repository First

Edit this repository directly:

```text
/home/coisini/i3-beige-dotfiles/config/i3
/home/coisini/i3-beige-dotfiles/config/polybar
/home/coisini/i3-beige-dotfiles/config/rofi
/home/coisini/i3-beige-dotfiles/config/picom
/home/coisini/i3-beige-dotfiles/config/dunst
/home/coisini/i3-beige-dotfiles/config/kitty
```

Then install the repo version into the live desktop:

```sh
./install.sh
i3-msg reload
```

This is the better long-term workflow after the setup becomes stable, because Git becomes the single source of truth.

Tradeoffs:

- Git is always up to date
- Every change is easy to diff, commit, and revert
- Requires applying changes back into `~/.config`
- A bad install can affect the live desktop, so review diffs first

### Recommended Path

Use Option 1 for now. Once the visual system and scripts settle down, switch to Option 2.

Avoid replacing the live config directories with symlinks until the repository workflow is fully stable. Symlinks are convenient, but a broken path or incomplete checkout can affect i3 startup and recovery.

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

These files are intentionally not versioned:

- `config/i3/workspace-output-routing.conf`
- `config/i3/display-layouts.conf`
- `config/kitty/current-bg`

Examples are included as `*.example`. The install script creates first-run copies when needed.

## Structure

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

## Notes

This setup assumes an X11 i3 session. Wayland compositors are out of scope.

Diagnosis note: [Picom lifecycle and Polybar width](doc/2026-06-04/picom-polybar-lifecycle-width-diagnosis.html).
