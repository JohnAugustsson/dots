#!/usr/bin/env fish
set -l mode $argv[1]
set -l scope $argv[2]
set -l start $argv[3]
set -l query $argv[4]

set -q mode[1]; or set mode path
set -q scope[1]; or set scope roots
set -q start[1]; or set start $PWD

set -l helper ~/.config/project-root-picker/scripts/project_root_picker.py
set -l excludes --exclude .git --exclude node_modules --exclude .svelte-kit --exclude dist --exclude build
set -l cols (tput cols 2>/dev/null; or echo 80)
# Preview takes about half the fzf width, so truncate for the list pane, not the full terminal.
set -l list_cols (math "max(20, floor($cols * 0.45))")
set -l display_width (math "max(20, $list_cols - 8)")

if test "$mode" = grep
    test -n "$query"; or exit 0
    $helper --scope $scope --start "$start" --grep "$query" 2>/dev/null
    exit $status
end

switch $scope
    case cwd
        set -l root (path resolve -- "$start" 2>/dev/null)
        test -n "$root"; or exit 1
        printf '\033[1;38;2;240;221;222m  ./\033[0m\t%s\n' "$root"
        fd --hidden --follow --type directory $excludes . "$root" 2>/dev/null \
        | awk -v root="$root" -v max="$display_width" 'function trunc(s) { return length(s) > max ? "…" substr(s, length(s) - max + 2) : s } BEGIN { reset="\033[0m"; dirc="\033[38;2;122;132;163m" } { path=$0; rel=path; sub("^" root "/?", "", rel); sub("/*$", "/", rel); print dirc "  " trunc(rel) reset "\t" path }'
        fd --hidden --follow --type file $excludes . "$root" 2>/dev/null \
        | awk -v root="$root" -v max="$display_width" 'function trunc(s) { return length(s) > max ? "…" substr(s, length(s) - max + 2) : s } BEGIN { reset="\033[0m"; dirc="\033[38;2;122;132;163m"; filec="\033[38;2;222;195;196m" } { path=$0; rel=path; sub("^" root "/?", "", rel); shown=trunc(rel); slash=match(shown, /\/[^\/]*$/); if (slash) print filec "  " dirc substr(shown, 1, slash) reset filec substr(shown, slash + 1) reset "\t" path; else print filec "  " filec shown reset "\t" path }'

    case home global
        set -l root ~
        printf '\033[1;38;2;240;221;222m  ~/\033[0m\t%s\n' "$root"
        fd --hidden --follow --type directory $excludes . "$root" 2>/dev/null \
        | awk -v root="$root" -v max="$display_width" 'function trunc(s) { return length(s) > max ? "…" substr(s, length(s) - max + 2) : s } BEGIN { reset="\033[0m"; dirc="\033[38;2;122;132;163m" } { path=$0; rel=path; sub("^" root "/?", "", rel); sub("/*$", "/", rel); print dirc "  " trunc(rel) reset "\t" path }'
        fd --hidden --follow --type file $excludes . "$root" 2>/dev/null \
        | awk -v root="$root" -v max="$display_width" 'function trunc(s) { return length(s) > max ? "…" substr(s, length(s) - max + 2) : s } BEGIN { reset="\033[0m"; dirc="\033[38;2;122;132;163m"; filec="\033[38;2;222;195;196m" } { path=$0; rel=path; sub("^" root "/?", "", rel); shown=trunc(rel); slash=match(shown, /\/[^\/]*$/); if (slash) print filec "  " dirc substr(shown, 1, slash) reset filec substr(shown, slash + 1) reset "\t" path; else print filec "  " filec shown reset "\t" path }'

    case '*'
        $helper --scope $scope --start "$start" 2>/dev/null
end
