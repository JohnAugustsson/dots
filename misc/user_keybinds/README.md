# user_keybinds

Portable **user-level** keyboard remap files for machines where you do **not** have sudo.

Nothing here is applied automatically. These files are only templates/assets to use on other workstations.

## What this remap mirrors

This mirrors the current keyd intent from `system/keyd/etc/keyd/default.conf` as closely as practical in user/session XKB:

- `AltGr+å` → `[`
- `AltGr+¨` → `]`
- `AltGr+ö` → `{`
- `AltGr+ä` → `}`
- `AltGr+.` → `(`
- `AltGr+-` → `)`
- `´` → `~`
- `Shift+´` → `^`
- `AltGr+´` → `´`
- `Shift+AltGr+´` → `` ` ``

## Directory layout

- `X11/` — generic X11 session usage via `setxkbmap`
- `Hyprland/` — wlroots/Hyprland-oriented full `.xkb` file
- `Sway/` — wlroots/Sway-oriented full `.xkb` file
- `KDE/` — KDE notes + X11 symbols file
- `GNOME/` — GNOME notes + X11 symbols file
- `common/` — shared reference copies

## Important limitation

User-level XKB is **session-level**, not system-level.

It usually works well for:
- your logged-in desktop session
- apps inside that session

It does **not** generally cover:
- TTYs
- login screens
- other users
- every Wayland compositor equally

## Quick environment matrix

### X11 session
Best no-sudo option.

Use:
```bash
setxkbmap -I"$HOME/dotfiles/misc/user_keybinds/X11/symbols" \
  -layout se-ja-keyd-like -variant ja_keyd_like
```

### Hyprland / wlroots
Use the full `.xkb` file if your compositor version supports custom keymap files.
See `Hyprland/README.md`.

### Sway / wlroots
Use the full `.xkb` file if your compositor version supports `xkb_file`.
See `Sway/README.md`.

### KDE
- **KDE X11**: use the same X11 path as above.
- **KDE Wayland**: support for fully custom user-home XKB files is less consistent; see `KDE/README.md`.

### GNOME
- **GNOME X11**: use the same X11 path as above.
- **GNOME Wayland**: custom user-home XKB loading is usually the weakest option here; see `GNOME/README.md`.

## File formats

### Symbols file
Used mainly for X11-style loading:
- `X11/symbols/se-ja-keyd-like`
- `KDE/symbols/se-ja-keyd-like`
- `GNOME/symbols/se-ja-keyd-like`
- `common/symbols/se-ja-keyd-like`

### Full keymap file
Used mainly for wlroots-style `xkb_file` loading:
- `Hyprland/ja-se-keyd-like.xkb`
- `Sway/ja-se-keyd-like.xkb`
- `common/ja-se-keyd-like.full.xkb`

## Rollback

If you test these on another machine and want to undo them:
- X11: re-run your normal `setxkbmap` command
- Hyprland/Sway: remove the custom `kb_file` / `xkb_file` setting and reload the compositor
- KDE/GNOME: switch back to the normal keyboard layout in session settings
