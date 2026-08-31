#!/usr/bin/env bash
set -euo pipefail

config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/waybar"
state_file="${XDG_STATE_HOME:-$HOME/.local/state}/waybar/theme"
theme="${WAYBAR_THEME:-}"

if [[ -z "$theme" && -r "$state_file" ]]; then
    IFS= read -r theme < "$state_file" || theme=""
fi
theme="${theme:-main}"

case "$theme" in
    main)
        style="$config_dir/style.css"
        ;;
    experimental|line|zen)
        style="$config_dir/themes/$theme.css"
        ;;
    *)
        printf 'Ignoring unknown Waybar theme %q; using main.\n' "$theme" >&2
        style="$config_dir/style.css"
        ;;
esac

waybar_bin="$(command -v waybar)" || {
    printf 'waybar is not installed or is not on PATH.\n' >&2
    exit 127
}

exec "$waybar_bin" --config "$config_dir/config" --style "$style"
