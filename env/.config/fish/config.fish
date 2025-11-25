#  Entry point that includes all other configs
#  
#  Author: [Dmitry](http://dmi3.net) [Source](https://github.com/dmi3/fish)

export GOPATH="$HOME/go"
export PATH="$PATH:$GOPATH/bin:/usr/local/go/bin:$HOME/.cargo/bin:$HOME/.local/scripts:$HOME/.config/bin:/home/linuxbrew/.linuxbrew/bin:$HOME/.local/share/bob/nvim-bin"

alias k=kubectl
alias tf=terraform
alias g=git
alias python=python3

kube_ps on
set fish_greeting

bind \cf "dev"

# DIRENV
function __direnv_export_eval --on-event fish_prompt
    direnv export fish | source
    if test "$direnv_fish_mode" != disable_arrow
        function __direnv_cd_hook --on-variable PWD
            if test "$direnv_fish_mode" = eval_after_arrow
                set -g __direnv_export_again 0
            else
                direnv export fish | source
            end
        end
    end
end

