complete -c project-root -s l -l list -d 'List saved root directories'
complete -c project-root -s c -l clean -d 'Remove missing root directories from the saved list'
complete -c project-root -l rm -d 'Remove current directory or PATH from the saved list'
complete -c project-root -s h -l help -d 'Show usage'

complete -c project-root -n '__fish_use_subcommand' -a '(__fish_complete_directories)'
complete -c project-root -n '__fish_seen_argument -l rm' -a '(__fish_complete_directories)'
