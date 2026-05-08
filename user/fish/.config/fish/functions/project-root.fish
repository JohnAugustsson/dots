function project-root
    set -l roots_file ~/.config/project-root-picker/project-roots
    mkdir -p ~/.config/project-root-picker
    test -f $roots_file; or touch $roots_file

    set -l mode add
    set -l target

    switch (count $argv)
        case 0
            set target $PWD
        case 1
            switch "$argv[1]"
                case -rm
                    set mode remove
                    set target $PWD
                case -l --list
                    set mode list
                case -c --clean
                    set mode clean
                case -h --help
                    set mode help
                case '*'
                    set target $argv[1]
            end
        case 2
            if test "$argv[1]" = "-rm"
                set mode remove
                set target $argv[2]
            else
                echo "usage: project-root [-rm PATH] [PATH] [-l|--list] [-c|--clean]" >&2
                return 1
            end
        case '*'
            echo "usage: project-root [-rm PATH] [PATH] [-l|--list] [-c|--clean]" >&2
            return 1
    end

    set -l existing
    if test -s $roots_file
        set existing (string split '\n' -- (string trim -- (cat $roots_file)))
    end

    switch $mode
        case help
            echo "project-root — manage root directories used by your fzf path picker"
            echo
            echo "Usage:"
            echo "  project-root             Add current directory"
            echo "  project-root PATH        Add PATH"
            echo "  project-root -rm         Remove current directory"
            echo "  project-root -rm PATH    Remove PATH"
            echo "  project-root -l          List saved root directories and discovered projects"
            echo "  project-root -c          Remove missing saved roots"
            echo "  project-root -h          Show this help"
            echo
            echo "Behavior:"
            echo "  - Saves directories as root scopes for Ctrl+F search"
            echo "  - Ctrl+F searches only inside saved roots"
            echo "  - project-root -l shows roots plus discovered projects in a tree-style view"
            return 0

        case list
            if test (count $existing) -eq 0
                echo "No root directories saved."
                return 0
            end

            set -l helper (path resolve ~/.config/project-root-picker/scripts/project_root_picker.py)
            set -l project_rows
            if test -x $helper
                set project_rows ($helper --projects-only --plain 2>/dev/null)
            end

            for dir in $existing
                test -n "$dir"; or continue
                set -l root (path resolve -- $dir 2>/dev/null)

                if test -z "$root"; or not test -d "$root"
                    echo "$dir [missing]"
                    continue
                end

                echo "$root"

                set -l children
                for row in $project_rows
                    set -l fields (string split \t -- $row)
                    test (count $fields) -ge 3; or continue

                    set -l project $fields[1]
                    set -l path (path resolve -- $fields[3] 2>/dev/null)
                    test -n "$path"; or continue
                    test "$path" != "$root"; or continue

                    if string match -q -- "$root/*" "$path"
                        set -l rel (string replace -- "$root/" "" "$path")
                        set children $children "$rel|$project"
                    end
                end

                set -l child_count (count $children)
                for i in (seq 1 $child_count)
                    set -l connector "├──"
                    if test $i -eq $child_count
                        set connector "└──"
                    end

                    set -l child_fields (string split "|" -- $children[$i])
                    set -l rel $child_fields[1]
                    set -l project $child_fields[2]

                    if test "$rel" = "$project"
                        echo "  $connector $rel"
                    else
                        echo "  $connector $rel ($project)"
                    end
                end
            end
            return 0

        case clean
            set -l kept
            set -l removed
            for dir in $existing
                test -n "$dir"; or continue
                if test -d "$dir"
                    set kept $kept "$dir"
                else
                    set removed $removed "$dir"
                end
            end

            printf '%s\n' $kept | string trim | awk 'NF && !seen[$0]++' > $roots_file

            if test (count $removed) -eq 0
                echo "No missing root directories to clean."
            else
                echo "Removed missing root directories:"
                for dir in $removed
                    echo "- $dir"
                end
            end
            return 0
    end

    set -l dir (path resolve -- $target)
    if test -z "$dir"; or not test -d "$dir"
        echo "project-root: not an existing directory: $target" >&2
        return 1
    end

    if test "$mode" = add

        if contains -- "$dir" $existing
            echo "Already tracked: $dir"
            return 0
        end

        printf '%s\n' $existing "$dir" | string trim | awk 'NF && !seen[$0]++' > $roots_file
        echo "Added root directory: $dir"
        return 0
    end

    set -l kept
    set -l found 0
    for line in $existing
        test -n "$line"; or continue
        if test "$line" = "$dir"
            set found 1
            continue
        end
        set kept $kept "$line"
    end

    printf '%s\n' $kept | string trim | awk 'NF && !seen[$0]++' > $roots_file

    if test $found -eq 1
        echo "Removed root directory: $dir"
    else
        echo "Root directory was not tracked: $dir"
    end
end
