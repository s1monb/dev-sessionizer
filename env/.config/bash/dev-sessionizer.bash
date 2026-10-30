# Shared dev-sessionizer bash setup (installed to ~/.config/bash/ by ./install.sh).
# Keep machine-specific overrides in ~/.bashrc instead.
# shellcheck disable=SC2034  # OSH_THEME, completions, aliases, plugins, … are read by oh-my-bash

case $- in
  *i*) ;;
    *) return;;
esac

# Path to oh-my-bash (installed by ./install.sh).
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

# Homebrew, from whichever prefix exists (Apple silicon, Intel macOS, Linux).
for __b in /opt/homebrew/bin/brew /usr/local/bin/brew /home/linuxbrew/.linuxbrew/bin/brew; do
  [[ -x $__b ]] && { eval "$("$__b" shellenv)"; break; }
done
unset __b

# Toolchains and local paths (from former fish config)
export GOPATH="$HOME/go"
export PATH="$HOME/.config/local/bin:$PATH:$GOPATH/bin:/usr/local/go/bin:$HOME/.cargo/bin:$HOME/.local/scripts:$HOME/.config/bin:$HOME/.local/share/bob/nvim-bin:$HOME/.local/bin"

alias tf=terraform
alias k=kubectl
alias g=git
alias python=python3
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

# kubectl, flux, talosctl completions etc. often need helpers from the bash-completion
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
    # shellcheck source=/dev/null
    [[ -f $__f ]] && source "$__f"
  done
  unset __f
fi
unset -f _ds_try_source_bash_completion
