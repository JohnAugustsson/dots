function __fzf_insert_global_path
    set -l search_root ~
    set -l path (
        fd --hidden --follow --exclude .git --exclude node_modules --exclude .svelte-kit --exclude dist --exclude build . "$search_root" 2>/dev/null \
        | fzf --preview 'if test -d {}; ls -la {}; else bat --style=plain --color=always {} 2>/dev/null; end'
    )

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
