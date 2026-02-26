#  Entry point that includes all other configs
#  
#  Author: [Dmitry](http://dmi3.net) [Source](https://github.com/dmi3/fish)

export GOPATH="$HOME/go"
export PATH="$PATH:$GOPATH/bin:/usr/local/go/bin:$HOME/.cargo/bin:$HOME/.local/scripts:/opt/nvim/bin:/home/linuxbrew/.linuxbrew/bin:/home/dev/.cargo/bin"

alias k=kubectl
alias tf=terraform
alias g=git

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

function __direnv_export_eval_2 --on-event fish_preexec
    if set -q __direnv_export_again
        set -e __direnv_export_again
        direnv export fish | source
        echo
    end
    functions --erase __direnv_cd_hook
end
function vagrant
    docker run -it --rm \
        -e LIBVIRT_DEFAULT_URI \
        -v /var/run/libvirt/:/var/run/libvirt/ \
        -v $HOME/.vagrant.d:/.vagrant.d \
        -v (realpath "$PWD"):$PWD \
        -w "$PWD" \
        --network host \
        vagrantlibvirt/vagrant-libvirt:latest \
        vagrant $argv
end

