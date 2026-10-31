#!/usr/bin/env bash
# Install or update every component into $HOME. Safe to re-run; never touches override files.
set -euo pipefail

# shellcheck source=lib.sh
source "$(dirname "$0")/lib.sh"

ds_check_prereqs || exit 1

ENV="$DS_ROOT/env"
installed=0

# Replace dest with a fresh copy of src.
replace() {
  rm -rf "$2"
  mkdir -p "$(dirname "$2")"
  cp -R "$1" "$2"
  installed=$((installed + 1))
}

mkdir -p "$HOME/.config/bash"
rm -f "$HOME/.config/bash/dev-sessionizer.bash"
cp "$ENV/.config/bash/dev-sessionizer.bash" "$HOME/.config/bash/dev-sessionizer.bash"
installed=$((installed + 1))

replace "$ENV/vendor/oh-my-bash" "$HOME/.config/oh-my-bash"
rm -rf "$HOME/.config/oh-my-bash/.git"
cp -R "$ENV/.config/oh-my-bash/custom/." "$HOME/.config/oh-my-bash/custom/"

replace "$ENV/.config/tmux" "$HOME/.config/tmux"
replace "$ENV/.config/nvim" "$HOME/.config/nvim"
replace "$ENV/.config/bin" "$HOME/.config/bin"
replace "$ENV/.config/sandbox" "$HOME/.config/sandbox"
replace "$ENV/.config/k9s" "$HOME/.config/k9s"

plugins="$HOME/.local/share/nvim/site/pack/vendor/start"
rm -rf "$plugins"
mkdir -p "$plugins"
for plugin in "$ENV"/vendor/nvim/*/; do
  cp -R "${plugin%/}" "$plugins/"
done
rm -rf "$plugins"/*/.git
installed=$((installed + 1))

# Optional completions: generated only for tools present on this machine.
completions="$HOME/.config/bash/completions"
rm -rf "$completions"
mkdir -p "$completions"
for tool in flux talosctl; do
  if command -v "$tool" >/dev/null 2>&1; then
    "$tool" completion bash >"$completions/$tool.bash" 2>/dev/null || rm -f "$completions/$tool.bash"
  fi
done
installed=$((installed + 1))

# Overrides are created once and are user-owned from then on; install never rewrites them.
[[ -e $HOME/.bashrc ]] || cp "$ENV/.bashrc.example" "$HOME/.bashrc"
mkdir -p "$HOME/.config/local/bin"
[[ -e $HOME/.config/local/nvim.lua ]] ||
  echo '-- machine-local overrides (never touched by install)' >"$HOME/.config/local/nvim.lua"
[[ -e $HOME/.config/local/tmux.conf ]] ||
  echo '# machine-local overrides (never touched by install)' >"$HOME/.config/local/tmux.conf"
if [[ ! -e $HOME/.config/local/sandbox.env ]]; then
  cat >"$HOME/.config/local/sandbox.env" <<'ENV'
# Environment for sandbox containers (never touched by install). Passed to Docker as --env-file:
# one KEY=value per line, no quotes, never sourced by a shell.
# Claude Code login for the sandbox, from `claude setup-token`:
# CLAUDE_CODE_OAUTH_TOKEN=
ENV
  chmod 600 "$HOME/.config/local/sandbox.env"
fi

ds_log "installed $installed components from $DS_ROOT"
