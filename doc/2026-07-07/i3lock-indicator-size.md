## Symptom

The current `i3lock` indicator circle is too small. The user wants to keep the
original ring-style lock screen, but make the ring larger and clearer.

## Hypothesis

The stock Ubuntu `i3lock` binary does not expose ring sizing flags. The
`i3lock-color` fork supports `--radius` and `--ring-width`, so the lock script
can prefer a locally built `i3lock-color` binary and fall back to stock `i3lock`
until that binary exists.

## Experiment Log

- Searched the repository for lock-screen entry points and found
  `config/i3/lock-screen.sh`.
- Checked the local `i3lock --help` output and confirmed the stock binary does
  not expose radius controls.
- Found an `i3lock-color` source checkout in the repository workspace.
- Installed the missing build dependencies incrementally and built
  `i3lock-color` successfully.
- Copied the resulting binary to `~/.local/bin/i3lock-color`.
- Updated the lock script to prefer `~/.local/bin/i3lock-color`, pass
  `--radius 1440` and `--ring-width 128` for the enlarged ring, and fall back to stock
  `i3lock` otherwise.
- Updated the README dependency list to document `i3lock` / `i3lock-color`.

## Conclusion

The runtime script now uses the locally built `i3lock-color` binary when it is
available, producing the original i3lock-style indicator with a much larger
ring. If the local binary is missing, it safely falls back to stock `i3lock`.
