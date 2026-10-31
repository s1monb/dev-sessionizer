# Shared helpers for install.sh, pack.sh, unpack.sh and tests/. Sourced, never executed.
# Must stay compatible with bash 3.2 (stock macOS /bin/bash).

DS_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

ds_os() { uname -s; }
ds_arch() { uname -m; }

ds_log() { printf 'dev-sessionizer: %s\n' "$*"; }
ds_err() { printf 'dev-sessionizer: %s\n' "$*" >&2; }

# Every path install owns, one per line. Install replaces these wholesale and never deletes
# anything else. A function rather than an array so it follows the current $HOME.
ds_managed() {
  printf '%s\n' \
    "$HOME/.config/bash/dev-sessionizer.bash" \
    "$HOME/.config/bash/completions" \
    "$HOME/.config/oh-my-bash" \
    "$HOME/.config/tmux" \
    "$HOME/.config/nvim" \
    "$HOME/.config/bin" \
    "$HOME/.config/sandbox" \
    "$HOME/.config/k9s" \
    "$HOME/.local/share/nvim/site/pack/vendor/start"
}

DS_PREREQS="bash git tmux nvim fzf tar find"

# Prints "major minor" from the first X.Y found in $1.
_ds_version() {
  if [[ $1 =~ ([0-9]+)\.([0-9]+) ]]; then
    printf '%s %s\n' "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}"
  fi
}

# Succeeds when version string $1 is at least $2.$3.
_ds_version_ok() {
  local major minor
  read -r major minor <<<"$(_ds_version "$1")"
  [[ -n $major ]] || return 1
  ((major > $2 || (major == $2 && minor >= $3)))
}

# Checks hard prerequisites and vendored folders. Reports every problem at once; writes nothing.
ds_check_prereqs() {
  local tool missing="" outdated="" line vendor failed=0

  for tool in $DS_PREREQS; do
    command -v "$tool" >/dev/null 2>&1 || missing="${missing:+$missing, }$tool"
  done

  if command -v nvim >/dev/null 2>&1; then
    # NVIM_LOG_FILE: otherwise nvim creates ~/.local/state/nvim/nvim.log, and this check must not write.
    line="$(NVIM_LOG_FILE=/dev/null nvim --version 2>/dev/null)"
    line="${line%%$'\n'*}"
    # 0.12: the vendored blink.cmp v2 refuses to load on older versions.
    _ds_version_ok "$line" 0 12 || outdated="$outdated  outdated: nvim ${line#NVIM v} (need >= 0.12)"$'\n'
  fi
  if command -v tmux >/dev/null 2>&1; then
    line="$(tmux -V 2>/dev/null)"
    _ds_version_ok "$line" 3 2 || outdated="$outdated  outdated: ${line} (need >= 3.2)"$'\n'
  fi

  if [[ -n $missing ]]; then
    ds_err "missing: $missing"
    failed=1
  fi
  if [[ -n $outdated ]]; then
    printf '%s' "$outdated" >&2
    failed=1
  fi
  ((failed == 0)) || return 1

  for vendor in "$DS_ROOT/env/vendor/oh-my-bash" "$DS_ROOT"/env/vendor/nvim/*; do
    if [[ ! -d $vendor ]] || ! compgen -G "$vendor/*" >/dev/null; then
      if [[ -e $DS_ROOT/.git ]]; then
        ds_err "vendored folder is empty: ${vendor#"$DS_ROOT"/}"
        ds_err "run: git submodule update --init --recursive"
      else
        ds_err "incomplete archive: ${vendor#"$DS_ROOT"/} missing"
      fi
      return 1
    fi
  done
}

# Refuses to continue unless HOME is a sandbox distinct from the real home.
ds_guard_sandbox_home() {
  if [[ ${DS_SANDBOX:-} != 1 || -z ${DS_REAL_HOME:-} || $HOME == "$DS_REAL_HOME" ]]; then
    ds_err "refusing to run: HOME ($HOME) is not a sandbox"
    return 1
  fi
}
