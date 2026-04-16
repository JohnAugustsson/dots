#!/usr/bin/env bash
set -euo pipefail

DIR="${1:-next}"

# Replace these with your real monitor names from: hyprctl monitors
MON1="DP-1"
MON2="DP-2"

focused_json="$(hyprctl monitors -j)"
focused_monitor="$(printf '%s\n' "$focused_json" | jq -r '.[] | select(.focused == true) | .name')"
current_ws="$(printf '%s\n' "$focused_json" | jq -r '.[] | select(.focused == true) | .activeWorkspace.id')"

target=""

if [[ "$focused_monitor" == "$MON1" ]]; then
  if [[ "$DIR" == "next" ]]; then
    case "$current_ws" in
    1) target=2 ;;
    2) target=3 ;;
    3) target=3 ;;
    *) target=1 ;;
    esac
  else
    case "$current_ws" in
    1) target=1 ;;
    2) target=1 ;;
    3) target=2 ;;
    *) target=1 ;;
    esac
  fi
elif [[ "$focused_monitor" == "$MON2" ]]; then
  if [[ "$DIR" == "next" ]]; then
    case "$current_ws" in
    4) target=5 ;;
    5) target=5 ;;
    *) target=4 ;;
    esac
  else
    case "$current_ws" in
    4) target=4 ;;
    5) target=4 ;;
    *) target=4 ;;
    esac
  fi
fi

if [[ -n "$target" ]]; then
  hyprctl dispatch focusworkspaceoncurrentmonitor "$target"
fi
