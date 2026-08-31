source /usr/share/cachyos-fish-config/cachyos-config.fish

function fv
    echo "stowu, stows, dots, cava, htop, minimized-wins"
end

function nvim-help
    echo "Mnemonic: v/d/c/y + i or a + \""
end

function img
    if test (count $argv) -eq 0
        printf 'usage: img <image-file> [kitten-icat-options...]\n' >&2
        return 1
    end

    kitten icat $argv
end

function minimized-wins
    ~/.config/hypr/scripts/hypr-hidden-min.py $argv
end

function fish_prompt
    echo
    set -l branch (git branch --show-current 2>/dev/null)
    if test -n "$branch"
        set -l upstream (git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null)

        set_color cyan
        if test -n "$upstream"
            echo "($branch -> $upstream)"
        else
            echo "($branch)"
        end
    end
    set_color green
    echo -n (whoami)"@"(hostname)
    set_color normal
    echo -n " "
    set_color blue
    echo ( prompt_pwd --full-length-dirs 10 )
    set_color normal
    echo -n "> "
end

fish_add_path ~/.npm-global/bin

# Let terminal TUIs/fzf receive Ctrl+S instead of XOFF freezing the terminal.
status is-interactive; and stty -ixon 2>/dev/null

set -Ux EDITOR nvim
set -Ux VISUAL nvim
set -Ux SSH_AUTH_SOCK ~/.ssh/agent.sock
alias dots "cd ~/dotfiles"
alias stowu "cd ~/dotfiles/user && stow -t ~ *"
alias stows "cd ~/dotfiles/system && sudo stow -t / *"
alias fav fv
alias logout hyprshutdown

# GitHub CLI shortcuts
alias pr 'gh pr'
alias prs 'gh pr list'
alias issue 'gh issue'
alias issues 'gh issue list'
alias repo 'gh repo'

function bw-tmux
    set -l socket_dir (set -q OPENCLAW_TMUX_SOCKET_DIR; and echo $OPENCLAW_TMUX_SOCKET_DIR; or echo /tmp/openclaw-tmux-sockets)
    mkdir -p "$socket_dir"

    set -l socket "$socket_dir/openclaw-bw.sock"
    set -l session "bw-auth-"(date +%Y%m%d-%H%M%S)

    tmux -S "$socket" new -d -s "$session" -n shell
    echo "Created Bitwarden tmux session: $session"
    echo "Socket: $socket"
    echo "Attach with: tmux -S $socket attach -t $session"
    tmux -S "$socket" attach -t "$session"
end

function bw-tmux-login
    set -l socket_dir (set -q OPENCLAW_TMUX_SOCKET_DIR; and echo $OPENCLAW_TMUX_SOCKET_DIR; or echo /tmp/openclaw-tmux-sockets)
    mkdir -p "$socket_dir"

    set -l socket "$socket_dir/openclaw-bw.sock"
    set -l session "bw-auth-"(date +%Y%m%d-%H%M%S)

    tmux -S "$socket" new -d -s "$session" -n shell

    echo "Created Bitwarden tmux session: $session"
    echo "Socket: $socket"
    echo "Inside tmux, run these commands:"
    echo "  bw login"
    echo "  set -x BW_SESSION (bw unlock --raw)"
    echo "  bw sync"
    echo "  bw status"
    echo
    echo "Attaching now..."
    tmux -S "$socket" attach -t "$session"
end

bind --erase --preset \cd
bind --erase --preset \ce
bind --erase --preset \cp
bind \ce exit
bind \cf __fzf_insert_path
bind \cg __fzf_insert_global_path
bind \cd __fzf_insert_project_path
bind \cb __fzf_insert_cwd_path

# z jump (zoxide)
zoxide init fish | source

# OpenClaw Completion
source "/home/ja/.openclaw/completions/openclaw.fish"

alias vim nvim
nvim-help
alias cd z
alias ls eza

# p4 environment setup
set -Ux P4PORT ssl:57.129.101.183:1666
set -Ux P4USER gooseboy
set -Ux P4CLIENT gooseboy
set -Ux P4EDITOR nvim
set -Ux P4IGNORE .p4ignore

if status is-interactive
    atuin init fish | source
end

thefuck --alias | source
