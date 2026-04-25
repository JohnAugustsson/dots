# Hyprland

This directory is for **user-level, not system-level** remapping on Hyprland.
Nothing here is applied automatically.

## File

- `ja-se-keyd-like.xkb` — full XKB keymap file

## Intended usage

If your Hyprland version supports a custom keyboard file, point `kb_file` at this file in your Hyprland config.

Example:
```ini
input {
    kb_file = /home/ja/dotfiles/misc/user_keybinds/Hyprland/ja-se-keyd-like.xkb
}
```

Then reload Hyprland.

## Notes

- This is meant for Hyprland sessions only.
- It is a no-sudo/session-level alternative to keyd.
- If a given workstation's Hyprland build does not support `kb_file`, fall back to:
  - system-level keyd if you have sudo, or
  - app-local remaps (like the Neovim-only version).
