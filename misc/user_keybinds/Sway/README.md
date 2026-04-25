# Sway

This directory is for **user-level, not system-level** remapping on Sway.
Nothing here is applied automatically.

## File

- `ja-se-keyd-like.xkb` — full XKB keymap file

## Intended usage

Point your keyboard input block at this file with `xkb_file`.

Example:
```ini
input type:keyboard {
    xkb_file /home/ja/dotfiles/misc/user_keybinds/Sway/ja-se-keyd-like.xkb
}
```

Then reload Sway.

## Notes

- This is session-level only.
- It is the closest no-sudo alternative here to keyd-like behavior.
- If a workstation or compositor setup refuses custom keymap files, fall back to X11 loading or app-local remaps.
