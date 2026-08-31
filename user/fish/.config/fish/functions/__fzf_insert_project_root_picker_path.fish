function __fzf_insert_project_root_picker_path
    set -l scope roots
    if test (count $argv) -ge 1
        set scope $argv[1]
    end

    set -l roots_file ~/.config/project-root-picker/project-roots
    set -l helper ~/.config/project-root-picker/scripts/project_root_picker.py
    set -l entries ~/.config/project-root-picker/scripts/project_root_picker_entries.py
    set -l preview ~/.config/project-root-picker/scripts/project_root_picker_preview.py
    set -l nav ~/.config/project-root-picker/scripts/project_root_picker_match_nav.py
    set -l state_file (mktemp -t project-root-picker-rg.XXXXXX)

    if not test -x $helper
        echo "Missing picker helper: $helper" >&2
        commandline -f repaint
        return 1
    end

    if not test -x $entries
        echo "Missing picker entries helper: $entries" >&2
        commandline -f repaint
        return 1
    end

    if not test -x $preview
        echo "Missing picker preview helper: $preview" >&2
        commandline -f repaint
        return 1
    end

    if not test -x $nav
        echo "Missing picker nav helper: $nav" >&2
        commandline -f repaint
        return 1
    end

    if test "$scope" = roots; and not test -f $roots_file
        echo "No project roots configured. Use: project-root" >&2
        commandline -f repaint
        return 1
    end

    set -l escaped_entries (string escape -- $entries)
    set -l escaped_preview (string escape -- $preview)
    set -l escaped_nav (string escape -- $nav)
    set -l escaped_scope (string escape -- $scope)
    set -l escaped_pwd (string escape -- "$PWD")
    set -l escaped_state (string escape -- "$state_file")

    set -l path_reload "$escaped_entries path $escaped_scope $escaped_pwd 2>/dev/null || true"
    set -l rg_reload "$escaped_entries grep $escaped_scope $escaped_pwd {q} 2>/dev/null || true"
    set -l picker_preview "$escaped_preview auto {q} $escaped_state {}"
    set -l nav_next "$escaped_nav $escaped_state 1 {q} {}"
    set -l nav_prev "$escaped_nav $escaped_state -1 {q} {}"

    set -l toggle_script "if test \"\$FZF_PROMPT\" = 'rg> '; echo 'change-prompt(path> )+reload($path_reload)+unbind(change)+enable-search'; else echo 'change-prompt(rg> )+reload($rg_reload)+rebind(change)+disable-search'; end"

    set -l selected (
        $entries path $scope "$PWD" \
        | fzf --delimiter '\t' --with-nth=1 --ansi --tiebreak=index \
            --prompt='path> ' \
            --bind 'ctrl-z:ignore' \
            --bind 'start:unbind(change)' \
            --bind "change:reload($rg_reload)" \
            --bind "ctrl-s:transform:$toggle_script" \
            --bind "ctrl-j:execute-silent($nav_next)+refresh-preview" \
            --bind "ctrl-l:execute-silent($nav_next)+refresh-preview" \
            --bind "ctrl-k:execute-silent($nav_prev)+refresh-preview" \
            --bind "ctrl-h:execute-silent($nav_prev)+refresh-preview" \
            --preview-window 'up,60%,border-bottom' \
            --preview "$picker_preview"
    )

    set -l status_code $pipestatus[1]
    command rm -f "$state_file" 2>/dev/null

    if test "$scope" = project; and test $status_code -ne 0
        echo "Not currently in a project working directory" >&2
        commandline -f repaint
        return 1
    end

    set -l path (printf '%s' "$selected" | cut -f2)

    if test -z "$path"
        commandline -f repaint
        return 0
    end

    set -l escaped (string escape -- "$path")
    set -l current (commandline)

    if test -n "$current"
        commandline -i -- "$escaped"
    else
        commandline -i -- " $escaped"
        commandline -f beginning-of-line
    end

    commandline -f repaint
end
