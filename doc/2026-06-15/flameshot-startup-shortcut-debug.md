## Symptom

- Flameshot did not start with the i3 session.
- `Win+Shift+S` did not open the Flameshot capture UI.

## Hypothesis

The initial config defined capture commands but did not start the Flameshot daemon.
After adding daemon startup, direct GUI invocation worked while the keysym shortcut
still did not trigger, narrowing the remaining fault to the i3 key binding.

## Experiment Log

- Flameshot 12.1.0 is installed at `/usr/bin/flameshot`.
- i3 loaded the expected config and contained the original keysym binding.
- X11 maps the Windows keys to `Mod4` and physical `S` (`AC02`) to keycode 39.
- No duplicate binding or key-grab warning was found.
- Direct `/usr/bin/flameshot gui` invocation displayed the capture overlay across
  both monitors, ruling out the GUI and D-Bus service as the remaining cause.
- Synthetic key injection was unavailable because `xdotool` is not installed.

## Conclusion

Start `/usr/bin/flameshot` with i3. Bind `Win+Shift+S` to physical keycode 39 and
execute on key release, avoiding keysym/layout translation and opening the capture
UI while Mod4 and Shift are still held. Use absolute paths for all capture commands.

Post-change validation passed: the smoke test and `i3 -C` succeeded, i3 reload
returned success, Flameshot remained running, and `org.flameshot.Flameshot` was
registered on the user D-Bus session.
