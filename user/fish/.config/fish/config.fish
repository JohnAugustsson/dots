source /usr/share/cachyos-fish-config/cachyos-config.fish

# overwrite greeting
# potentially disabling fastfetch
#function fish_greeting
#    echo "smth smth"
#end

function fv
    echo "stowu, stows, dots, cava, htop, minimized-wins"
end

function minimized-wins
    ~/.config/hypr/scripts/hypr-hidden-min.py $argv
end

function fish_prompt
    echo
    set_color green
    echo -n (whoami)"@"(hostname)
    set_color normal
    echo -n " "
    set_color blue
    echo (prompt_pwd)
    set_color normal
    echo -n "> "
end

fish_add_path ~/.npm-global/bin

set -x LD_LIBRARY_PATH /usr/local/lib
set -Ux EDITOR nvim
set -Ux VISUAL nvim
set -Ux SSH_AUTH_SOCK ~/.ssh/agent.sock
alias unrealEngine 'env SDL_VIDEODRIVER=x11 ~/unreal/unreal_engine/Engine/Binaries/Linux/UnrealEditor'
alias dots "cd ~/dotfiles"
alias stowu "cd ~/dotfiles/user && stow -t ~ *"
alias stows "cd ~/dotfiles/system && sudo stow -t / *"
alias fav fv

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

# OpenClaw Completion
source "/home/ja/.openclaw/completions/openclaw.fish"
