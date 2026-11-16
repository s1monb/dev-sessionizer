#!/usr/bin/env bash
# Unpack: run from inside the extracted archive (tar -xzf dev-sessionizer.tar.gz).
# Installs everything, loads the sandbox image when the archive has one, then restores runtime
# state when the archive was made on this platform.
set -euo pipefail

# shellcheck source=lib.sh
source "$(dirname "$0")/lib.sh"

# Same interpreter as this script, so the bash 3.2 guarantee covers install too.
"$BASH" "$DS_ROOT/install.sh"

os="" arch="" sandbox_uid="" sandbox_gid="" sandbox_arch=""
while IFS='=' read -r key value; do
  case "$key" in
    os) os="$value" ;;
    arch) arch="$value" ;;
    sandbox_uid) sandbox_uid="$value" ;;
    sandbox_gid) sandbox_gid="$value" ;;
    sandbox_arch) sandbox_arch="$value" ;;
  esac
done <"$DS_ROOT/MANIFEST"

# The sandbox image never fails unpack: when it cannot be loaded, say why and how to do it later.
load_sandbox_image() {
  local tar="$DS_ROOT/sandbox-image.tar" here later
  [[ -f $tar ]] || return 0
  later="load it later with: docker load -i \"$tar\" && docker tag dev-sessionizer-sandbox:packed dev-sessionizer-sandbox:latest"
  here="$(ds_docker_arch || uname -m)"
  if [[ $sandbox_arch != "$here" ]]; then
    ds_err "sandbox image not loaded: it is for $sandbox_arch, this machine is $here"
    return 0
  fi
  if ! command -v docker >/dev/null 2>&1; then
    ds_err "sandbox image not loaded: docker not found; $later"
    return 0
  fi
  if ! docker info >/dev/null 2>&1; then
    ds_err "sandbox image not loaded: cannot reach the Docker daemon; $later"
    return 0
  fi
  if ! docker load -i "$tar" >/dev/null ||
    ! docker tag dev-sessionizer-sandbox:packed dev-sessionizer-sandbox:latest; then
    ds_err "sandbox image not loaded: docker failed (see above); $later"
    return 0
  fi
  docker image rm dev-sessionizer-sandbox:packed >/dev/null 2>&1 || true
  ds_log "loaded sandbox image for uid $sandbox_uid gid $sandbox_gid"
  if [[ $sandbox_uid != "$(id -u)" || $sandbox_gid != "$(id -g)" ]]; then
    ds_err "warning: you are uid $(id -u) gid $(id -g); sandbox will refuse this image for you"
  fi
}
load_sandbox_image

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
