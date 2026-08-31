#!/usr/bin/env bash

set -euo pipefail

geometry="$(slurp)" || exit 0
[[ -n "$geometry" ]] || exit 0

pictures_dir="$(xdg-user-dir PICTURES 2>/dev/null || true)"
if [[ -z "$pictures_dir" ]]; then
	pictures_dir="${HOME}/Pictures"
fi

screenshots_dir="${pictures_dir}/Screenshots"
mkdir -p "$screenshots_dir"

timestamp="$(date +'%Y-%m-%d_%H-%M-%S-%N')"
screenshot_path="${screenshots_dir}/Screenshot_${timestamp}.png"

if ! grim -g "$geometry" "$screenshot_path"; then
	notify-send -u critical "Screenshot failed" "grim could not capture the selected region"
	exit 1
fi

wl-copy --type image/png < "$screenshot_path"
notify-send -a Screenshot -i "$screenshot_path" "Screenshot captured" "Saved to $screenshot_path and copied to the clipboard"
