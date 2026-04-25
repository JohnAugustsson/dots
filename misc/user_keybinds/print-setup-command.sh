#!/usr/bin/env bash
set -euo pipefail

ROOT="${HOME}/dotfiles/misc/user_keybinds"
SESSION_TYPE="${XDG_SESSION_TYPE:-unknown}"
DESKTOP="${XDG_CURRENT_DESKTOP:-${DESKTOP_SESSION:-unknown}}"
DESKTOP_UPPER="$(printf '%s' "$DESKTOP" | tr '[:lower:]' '[:upper:]')"

printf 'Session type: %s\n' "$SESSION_TYPE"
printf 'Desktop: %s\n\n' "$DESKTOP"
printf 'Nothing will be applied automatically.\n'
printf 'Run the matching command/config manually on the target workstation.\n\n'

if [[ "$SESSION_TYPE" == "x11" ]]; then
  cat <<'EOF'
Recommended path: X11

Command:
setxkbmap -I"$HOME/dotfiles/misc/user_keybinds/X11/symbols" \
  -layout se-ja-keyd-like -variant ja_keyd_like
EOF
  exit 0
fi

case "$DESKTOP_UPPER" in
  *HYPRLAND*)
    cat <<'EOF'
Recommended path: Hyprland

Add this to your Hyprland config:
input {
    kb_file = /home/ja/dotfiles/misc/user_keybinds/Hyprland/ja-se-keyd-like.xkb
}

Then reload Hyprland.
EOF
    ;;
  *SWAY*)
    cat <<'EOF'
Recommended path: Sway

Add this to your Sway config:
input type:keyboard {
    xkb_file /home/ja/dotfiles/misc/user_keybinds/Sway/ja-se-keyd-like.xkb
}

Then reload Sway.
EOF
    ;;
  *KDE*|*PLASMA*)
    cat <<'EOF'
Recommended path: KDE

KDE X11:
setxkbmap -I"$HOME/dotfiles/misc/user_keybinds/KDE/symbols" \
  -layout se-ja-keyd-like -variant ja_keyd_like

KDE Wayland:
Custom user-home XKB loading is workstation-dependent.
If custom keymap files are supported there, use:
  /home/ja/dotfiles/misc/user_keybinds/Hyprland/ja-se-keyd-like.xkb
Otherwise fall back to app-local remaps or system-level keyd when available.
EOF
    ;;
  *GNOME*)
    cat <<'EOF'
Recommended path: GNOME

GNOME X11:
setxkbmap -I"$HOME/dotfiles/misc/user_keybinds/GNOME/symbols" \
  -layout se-ja-keyd-like -variant ja_keyd_like

GNOME Wayland:
Usually the weakest option for custom user-home XKB files.
Prefer GNOME X11 if you need this exact remap without sudo.
EOF
    ;;
  *)
    cat <<'EOF'
Recommended path: generic fallback

X11 sessions:
setxkbmap -I"$HOME/dotfiles/misc/user_keybinds/X11/symbols" \
  -layout se-ja-keyd-like -variant ja_keyd_like

wlroots compositors:
- Hyprland file: /home/ja/dotfiles/misc/user_keybinds/Hyprland/ja-se-keyd-like.xkb
- Sway file:     /home/ja/dotfiles/misc/user_keybinds/Sway/ja-se-keyd-like.xkb
EOF
    ;;
esac
