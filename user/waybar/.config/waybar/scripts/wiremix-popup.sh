#!/usr/bin/env bash

# Reuse a single popup if it already exists
if hyprctl clients -j | grep "wiremix-popup"; then
  hyprctl dispatch killwindow "class:(wiremix-popup)"
  exit 0
fi

kitty \
  --class wiremix-popup \
  --title wiremix-popup \
  --override remember_window_size=no \
  --override initial_window_width=900 \
  --override initial_window_height=520 \
  wiremix
