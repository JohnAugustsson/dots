source /usr/share/cachyos-fish-config/cachyos-config.fish

# overwrite greeting
# potentially disabling fastfetch
#function fish_greeting
#    # smth smth
#end
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

set -x LD_LIBRARY_PATH /usr/local/lib
set -Ux EDITOR nvim
set -Ux VISUAL nvim
set -Ux SSH_AUTH_SOCK ~/.ssh/agent.sock
alias unrealEngine 'env SDL_VIDEODRIVER=x11 ~/unreal/unreal_engine/Engine/Binaries/Linux/UnrealEditor'
alias dots "cd ~/dotfiles"
alias stowu "cd ~/dotfiles/user && stow -t ~ *"
alias stows "cd ~/dotfiles/system && sudo stow -t / *"
