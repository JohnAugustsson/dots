#!/usr/bin/env fish
set -l state_file $argv[1]
set -l delta $argv[2]
set -l query $argv[3]
set -l row $argv[4]

set -l path (printf '%s' "$row" | cut -f2)
test -n "$state_file"; or exit 0
test -n "$path"; or exit 0
test -f "$path"; or exit 0
test -n "$query"; or exit 0

~/.config/project-root-picker/scripts/project_root_picker_match.py nav --state "$state_file" --query "$query" --path "$path" --delta "$delta"
