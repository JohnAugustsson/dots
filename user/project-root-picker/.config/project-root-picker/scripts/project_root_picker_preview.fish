#!/usr/bin/env fish
set -l mode $argv[1]
set -l query $argv[2]
set -l state_file $argv[3]
set -l row $argv[4]

if test "$mode" = auto
    if test "$FZF_PROMPT" = "rg> "
        set mode grep
    else
        set mode path
    end
end

set -l path (printf '%s' "$row" | cut -f2)
test -n "$path"; or exit 0

if test "$mode" = grep
    if test -f "$path"
        ~/.config/project-root-picker/scripts/project_root_picker_match.py preview --state "$state_file" --query "$query" --path "$path"
    else if test -d "$path"
        eza -la --group-directories-first --icons=always "$path" 2>/dev/null; or ls -la "$path"
    end
    exit 0
end

if test -d "$path"
    eza -la --group-directories-first --icons=always "$path" 2>/dev/null; or ls -la "$path"
else
    bat --style=plain --color=always "$path" 2>/dev/null
end
