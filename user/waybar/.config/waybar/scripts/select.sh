#!/usr/bin/env bash
set -euo pipefail

state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/waybar"
state_file="$state_dir/theme"
asset_dir="${XDG_CONFIG_HOME:-$HOME/.config}/waybar/assets"
themes=(main experimental line zen)
theme="${1:-}"

theme_menu() {
    local candidate

    for candidate in "${themes[@]}"; do
        printf '%s\0icon\x1f%s/%s.png\n' "$candidate" "$asset_dir" "$candidate"
    done
}

if [[ -z "$theme" ]]; then
    if ! command -v rofi >/dev/null 2>&1; then
        printf 'Usage: %s {main|experimental|line|zen}\n' "$0" >&2
        exit 2
    fi

    theme="$(theme_menu | rofi -dmenu -show-icons -p 'Waybar theme')" || exit 0
fi

case "$theme" in
    main|experimental|line|zen) ;;
    *)
        printf 'Unknown Waybar theme: %s\n' "$theme" >&2
        exit 2
        ;;
esac

install -d -m 700 "$state_dir"
temporary_state="$(mktemp "$state_dir/theme.XXXXXX")"
trap '[[ -z "${temporary_state:-}" ]] || rm -f -- "$temporary_state"' EXIT
printf '%s\n' "$theme" > "$temporary_state"
mv -- "$temporary_state" "$state_file"
temporary_state=""

systemctl --user daemon-reload
systemctl --user restart waybar.service
printf 'Waybar theme set to %s\n' "$theme"
