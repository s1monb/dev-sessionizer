# Shared dev-sessionizer bash setup (installed to ~/.config/bash/ by task install-locally).
# Keep machine-specific overrides in ~/.bashrc instead.

case $- in
  *i*) ;;
    *) return;;
esac

# Path to oh-my-bash (deployed by task install-locally).
export OSH="${OSH:-$HOME/.config/oh-my-bash}"

OSH_THEME="dev-sessionizer"

OMB_USE_SUDO=true

completions=(
  git
  composer
  ssh
  kubectl
)

aliases=(
  general
)

plugins=(
  git
  bashmarks
  kubectl
  kube-ps
)

source "$OSH"/oh-my-bash.sh

# Toolchains and local paths (from former fish config)
export GOPATH="$HOME/go"
export PATH="$PATH:$GOPATH/bin:/usr/local/go/bin:$HOME/.cargo/bin:$HOME/.local/scripts:$HOME/.config/bin:/home/linuxbrew/.linuxbrew/bin:$HOME/.local/share/bob/nvim-bin:$HOME/.local/bin"

alias tf=terraform
alias k=kubectl
alias g=git
alias python=python3
alias ifi="ssh -Y -J simobj@login.uio.no simobj@login.ifi.uio.no"
alias ecs=esc-caps-swap

# Match previous fish default (kube_ps on)
export __KUBE_PS_ENABLED=1

jwt-decode() {
  echo "$1" | jq -R 'split(".") | .[0:2] | map(gsub("-"; "+") | gsub("_"; "/") | gsub("%3D"; "=") | @base64d) | map(fromjson)'
}

if command -v direnv &>/dev/null; then
  eval "$(direnv hook bash)"
fi

if [[ ${BASH_VERSINFO[0]} -ge 4 ]] && [[ -o interactive ]]; then
  bind -x '"\C-f": dev' 2>/dev/null || true
fi

# go-task, kubectl plugins, etc. often need helpers from the bash-completion
# package (_init_completion, _filedir, …). OMB's bourne-shell only checks FHS
# paths; try a few more, then install `bash-completion` if completions still break.
_ds_try_source_bash_completion() {
  type -t _init_completion &>/dev/null && return 0
  local __bc
  for __bc in \
    /usr/share/bash-completion/bash_completion \
    /usr/local/share/bash-completion/bash_completion \
    /etc/bash_completion \
    /opt/homebrew/share/bash-completion/bash_completion \
    /opt/homebrew/etc/profile.d/bash_completion.sh; do
    if [[ -f $__bc ]]; then
      # shellcheck source=/dev/null
      source "$__bc"
      type -t _init_completion &>/dev/null && return 0
    fi
  done
  return 1
}

if [[ -d $HOME/.config/bash/completions ]]; then
  _ds_try_source_bash_completion || true
  for __f in "$HOME"/.config/bash/completions/*.bash; do
    [[ -f $__f ]] && source "$__f"
  done
  unset __f
fi
unset -f _ds_try_source_bash_completion
