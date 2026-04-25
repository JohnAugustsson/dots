function __fzf_insert_path
    set -l roots_file ~/.config/fish/project-roots
    if not test -f $roots_file
        echo "No project roots configured. Use: project-root" >&2
        commandline -f repaint
        return 1
    end

    set -l helper ~/.config/fish/scripts/project_root_picker.py
    if not test -x $helper
        echo "Missing picker helper: $helper" >&2
        commandline -f repaint
        return 1
    end

    set -l selected (
        $helper \
        | fzf --delimiter '\t' --with-nth=1 --ansi --tiebreak=index --preview 'set -l path (printf "%s" {} | cut -f2); if test -d "$path"; eza -la --group-directories-first --icons=always "$path" 2>/dev/null; or ls -la "$path"; else bat --style=plain --color=always "$path" 2>/dev/null; end'
    )

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
