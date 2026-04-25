# X11

This is the cleanest generic **no-sudo** path when the workstation is running an X11 session.
Nothing here is applied automatically.

## File

- `symbols/se-ja-keyd-like` — custom XKB symbols file

## Use it

```bash
setxkbmap -I"$HOME/dotfiles/misc/user_keybinds/X11/symbols" \
  -layout se-ja-keyd-like -variant ja_keyd_like
```

That adds this directory to the XKB search path and loads the custom variant from the local symbols file.

## Revert

Run your normal layout command again, for example:
```bash
setxkbmap se
```
or whatever your usual layout/variant is.
