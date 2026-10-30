#!/usr/bin/env bash
# Pack the installable tree and Neovim runtime state into one archive: ./pack.sh [OUTPUT]
set -euo pipefail

# shellcheck source=lib.sh
source "$(dirname "$0")/lib.sh"

out="${1:-$PWD/dev-sessionizer.tar.gz}"
outdir="$(dirname "$out")"
if [[ ! -d $outdir || ! -w $outdir ]]; then
  ds_err "cannot write to $outdir"
  exit 1
fi
out="$(cd "$outdir" && pwd)/$(basename "$out")"

stage="$(mktemp -d)"
trap 'rm -rf "$stage"' EXIT
dest="$stage/dev-sessionizer"
mkdir -p "$dest"

cp "$DS_ROOT/install.sh" "$DS_ROOT/unpack.sh" "$DS_ROOT/lib.sh" "$DS_ROOT/README.md" "$dest/"
cp -R "$DS_ROOT/env" "$dest/env"
find "$dest/env" -name .git -prune -exec rm -rf {} +

# Runtime state, only what exists. Plugins are left out: install provides them.
if [[ -d $HOME/.local/share/nvim ]]; then
  mkdir -p "$dest/runtime/share"
  cp -R "$HOME/.local/share/nvim" "$dest/runtime/share/nvim"
  rm -rf "$dest/runtime/share/nvim/site/pack/vendor"
fi
if [[ -d $HOME/.local/state/nvim ]]; then
  mkdir -p "$dest/runtime/state"
  cp -R "$HOME/.local/state/nvim" "$dest/runtime/state/nvim"
fi

printf 'os=%s\narch=%s\ncreated=%s\n' "$(ds_os)" "$(ds_arch)" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >"$dest/MANIFEST"

tar -czf "$out" -C "$stage" dev-sessionizer
ds_log "packed $out"
