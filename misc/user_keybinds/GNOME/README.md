# GNOME

Nothing here is applied automatically. This directory is a **dotfiles asset** for other machines.

## Files

- `symbols/se-ja-keyd-like` — custom XKB symbols file for GNOME **X11** sessions

## GNOME X11

Use the same generic X11 command:

```bash
setxkbmap -I"$HOME/dotfiles/misc/user_keybinds/GNOME/symbols" \
  -layout se-ja-keyd-like -variant ja_keyd_like
```

## GNOME Wayland

GNOME Wayland is usually the least friendly place for fully custom user-home XKB loading.
Practical rule:

- GNOME **X11**: good no-sudo option
- GNOME **Wayland**: often easier to treat as unsupported for this kind of custom user-local file unless that workstation has a known working setup

If GNOME Wayland refuses it, use:
- keyd on machines where you have sudo, or
- app-local remaps where you do not
