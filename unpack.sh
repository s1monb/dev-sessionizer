#!/usr/bin/env bash
# Unpack: run from inside the extracted archive (tar -xzf dev-sessionizer.tar.gz).
# Installs everything, then restores runtime state when the archive was made on this platform.
set -euo pipefail

# shellcheck source=lib.sh
source "$(dirname "$0")/lib.sh"

# Same interpreter as this script, so the bash 3.2 guarantee covers install too.
"$BASH" "$DS_ROOT/install.sh"

os="" arch=""
while IFS='=' read -r key value; do
  case "$key" in
    os) os="$value" ;;
    arch) arch="$value" ;;
  esac
done <"$DS_ROOT/MANIFEST"

if [[ $os != "$(ds_os)" || $arch != "$(ds_arch)" ]]; then
  ds_err "runtime state from $os/$arch skipped on $(ds_os)/$(ds_arch)"
  exit 0
fi

# Replace, not merge: the result matches unpacking onto a clean machine.
share="$HOME/.local/share/nvim"
if [[ -d $DS_ROOT/runtime/share/nvim ]]; then
  mkdir -p "$share"
  find "$share" -mindepth 1 -maxdepth 1 ! -name site -exec rm -rf {} +
  cp -R "$DS_ROOT/runtime/share/nvim/." "$share/"
fi

state="$HOME/.local/state/nvim"
if [[ -d $DS_ROOT/runtime/state/nvim ]]; then
  rm -rf "$state"
  mkdir -p "$(dirname "$state")"
  cp -R "$DS_ROOT/runtime/state/nvim" "$state"
fi

ds_log "restored runtime state from $os/$arch"
