#!/usr/bin/env bash
set -euo pipefail

# Reuse a single popup if it already exists
if hyprctl -j clients | jq -e 'any(.[]; .class == "wiremix-popup")' >/dev/null; then
	hyprctl dispatch 'hl.dsp.window.kill({ window = "class:wiremix-popup" })'
	exit 0
fi

kitty \
    --class wiremix-popup \
    --title wiremix-popup \
    --override remember_window_size=no \
    --override initial_window_width=900 \
    --override initial_window_height=520 \
    wiremix
