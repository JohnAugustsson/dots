#!/usr/bin/env bash

set -euo pipefail

card=""
for candidate in /sys/class/drm/card*/device; do
  [[ -r "$candidate/gpu_busy_percent" && -r "$candidate/mem_info_vram_used" && -r "$candidate/mem_info_vram_total" ]] || continue
  card="$candidate"
  break
done

[[ -n "$card" ]] || exit 1

case "${1:-all}" in
  gpu)
    printf "󰢮  %d%%\n" "$(<"$card/gpu_busy_percent")"
    ;;
  vram)
    vram_used=$(<"$card/mem_info_vram_used")
    vram_total=$(<"$card/mem_info_vram_total")
    awk -v used="$vram_used" -v total="$vram_total" '
      BEGIN {
        gib = 1024 * 1024 * 1024
        printf "󰍛 %.1fG/%.1fG\n", used / gib, total / gib
      }
    '
    ;;
  *)
    gpu=$(<"$card/gpu_busy_percent")
    vram_used=$(<"$card/mem_info_vram_used")
    vram_total=$(<"$card/mem_info_vram_total")
    awk -v gpu="$gpu" -v used="$vram_used" -v total="$vram_total" '
      BEGIN {
        gib = 1024 * 1024 * 1024
        printf "󰢮 %d%% 󰍛 %.1fG/%.1fG\n", gpu, used / gib, total / gib
      }
    '
    ;;
esac
