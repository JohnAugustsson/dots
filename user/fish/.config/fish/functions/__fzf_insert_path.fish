function __fzf_insert_path
    set -l roots_file ~/.config/fish/project-roots
    if not test -f $roots_file
        echo "No project roots configured. Use: project-root" >&2
        commandline -f repaint
        return 1
    end

    set -l roots
    while read -l line
        set line (string trim -- "$line")
        test -n "$line"; or continue
        test -d "$line"; or continue
        set roots $roots "$line"
    end < $roots_file

    if test (count $roots) -eq 0
        echo "No existing project roots configured. Use: project-root PATH" >&2
        commandline -f repaint
        return 1
    end

    set -l sorted_roots (
        for root in $roots
            printf '%s\t%s\n' (string length -- "$root") "$root"
        end | sort -rn | cut -f2-
    )

    set -l tmp (mktemp)
    set -l seen_paths
    set -l max_name_len 0

    for root in $sorted_roots
        set -l root_regex (string escape --style=regex -- "$root")
        set -l root_name (basename "$root")
        set -l entries "$root"
        set entries $entries (fd --hidden --follow --exclude .git --exclude node_modules --exclude .svelte-kit --exclude dist --exclude build . "$root" 2>/dev/null)

        for entry in $entries
            contains -- "$entry" $seen_paths; and continue
            set seen_paths $seen_paths "$entry"

            set -l rel_path
            set -l kind
            set -l label_dir

            if test "$entry" = "$root"
                set rel_path ./
                set kind root
                set label_dir "$root"
            else
                set rel_path (string replace -r "^$root_regex/?" "" -- "$entry")
                if test -d "$entry"
                    set rel_path "$rel_path/"
                    set kind dir
                    set label_dir "$entry"
                else
                    set kind file
                    set label_dir (path dirname "$entry")
                end
            end

            set -l project_name "$root_name"
            set -l project_dir ""
            set -l probe "$label_dir"
            while true
                if test -e "$probe/.project-root"; or test -e "$probe/.gitignore"
                    set project_name (basename "$probe")
                    set project_dir "$probe"
                    break
                end

                if test "$probe" = "$root"
                    break
                end

                set -l parent (path dirname "$probe")
                if test "$parent" = "$probe"
                    break
                end
                set probe "$parent"
            end

            if test -n "$project_dir"; and test "$entry" = "$project_dir"
                set rel_path ./
                set kind root
            end

            set -l name_len (string length -- "$project_name")
            if test $name_len -gt $max_name_len
                set max_name_len $name_len
            end

            printf '%s\t%s\t%s\t%s\n' "$project_name" "$rel_path" "$entry" "$kind" >> $tmp
        end
    end

    set -l selected (
        awk -F '\t' -v width="$max_name_len" '
            BEGIN {
                reset = "\033[0m"
                project = "\033[1;38;2;214;144;152m"
                root = "\033[1;38;2;240;221;222m"
                dir = "\033[38;2;122;132;163m"
                file = "\033[38;2;222;195;196m"
                icon_root = root
                icon_dir = dir
                icon_file = file
            }
            {
                kind_icon = ($4 == "root" ? "" : ($4 == "dir" ? "" : ""))
                kind_color = ($4 == "root" ? root : ($4 == "dir" ? dir : file))
                icon_color = ($4 == "root" ? icon_root : ($4 == "dir" ? icon_dir : icon_file))
                printf "%s%-*s%s  %s%s%s  %s%s%s\t%s\n",
                    project, width, $1, reset,
                    icon_color, kind_icon, reset,
                    kind_color, $2, reset,
                    $3
            }
        ' $tmp \
        | fzf --delimiter '\t' --with-nth=1 --ansi --tiebreak=index --preview 'set -l path (printf "%s" {} | cut -f2); if test -d "$path"; eza -la --group-directories-first --icons=always "$path" 2>/dev/null; or ls -la "$path"; else bat --style=plain --color=always "$path" 2>/dev/null; end'
    )
    rm -f $tmp

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
