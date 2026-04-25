# KDE

Nothing here is applied automatically. This directory is a **dotfiles asset** for other machines.

## Files

- `symbols/se-ja-keyd-like` — custom XKB symbols file for KDE **X11** sessions

## KDE X11

Use the same generic X11 command:

```bash
setxkbmap -I"$HOME/dotfiles/misc/user_keybinds/KDE/symbols" \
  -layout se-ja-keyd-like -variant ja_keyd_like
```

## KDE Wayland

KDE Wayland can be less consistent for fully custom user-home XKB loading.
Practical rule:

- if the workstation lets you point the session at a custom XKB file, use that
- otherwise use:
  - keyd on machines where you do have sudo, or
  - editor/app-local remaps on machines where you do not

So: KDE **X11** is the reliable no-sudo path here; KDE **Wayland** is more workstation-dependent.
