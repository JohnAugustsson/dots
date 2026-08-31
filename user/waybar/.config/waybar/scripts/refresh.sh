#!/usr/bin/env bash
set -euo pipefail

systemctl --user reload-or-restart waybar.service

