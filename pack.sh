#!/usr/bin/env bash
# Pack the installable tree and Neovim runtime state into one archive:
#   ./pack.sh [--uid N --gid N [--arch amd64|arm64]] [OUTPUT]
# With --uid/--gid the sandbox image is built for that user and included (needs Docker).
set -euo pipefail

# shellcheck source=lib.sh
source "$(dirname "$0")/lib.sh"

usage() {
  cat <<'EOF'
Usage: ./pack.sh [--uid N --gid N [--arch amd64|arm64]] [OUTPUT]

Writes OUTPUT (default ./dev-sessionizer.tar.gz) with the environment and Neovim runtime state.

  --uid N, --gid N  also build the agent sandbox image for this user on the target machine
                    (run `id -u` and `id -g` there) and include it; needs Docker
  --arch A          target architecture for the image: amd64 or arm64 (default: this machine's)
  -h, --help        show this help
EOF
}

die() {
  ds_err "$*"
  exit 1
}

out="" uid="" gid="" arch=""
while (($#)); do
  case "$1" in
    -h | --help) usage; exit 0 ;;
    --uid | --gid | --arch)
      (($# > 1)) || die "$1 needs a value"
      case "$1" in
        --uid) uid="$2" ;;
        --gid) gid="$2" ;;
        --arch) arch="$2" ;;
      esac
      shift
      ;;
    -*) die "unknown option: $1 (see ./pack.sh --help)" ;;
    *)
      [[ -z $out ]] || die "only one OUTPUT allowed"
      out="$1"
      ;;
  esac
  shift
done

image=0
if [[ -n $uid || -n $gid ]]; then
  [[ -n $uid && -n $gid ]] || die "--uid and --gid go together"
  for id in "$uid" "$gid"; do
    [[ $id =~ ^[0-9]+$ ]] || die "not a numeric id: $id"
    ((10#$id != 0)) || die "refusing to pack the sandbox image for root (id 0)"
  done
  if [[ -z $arch ]]; then
    arch="$(ds_docker_arch)" || die "unknown architecture $(uname -m); pass --arch amd64 or --arch arm64"
  fi
  case "$arch" in
    amd64 | arm64) ;;
    *) die "unsupported architecture: $arch (amd64, arm64)" ;;
  esac
  command -v docker >/dev/null 2>&1 || die "docker not found; it is needed to pack the sandbox image"
  docker info >/dev/null 2>&1 || die "cannot reach the Docker daemon; is it running?"
  image=1
elif [[ -n $arch ]]; then
  die "--arch only applies with --uid and --gid"
fi

out="${out:-$PWD/dev-sessionizer.tar.gz}"
outdir="$(dirname "$out")"
if [[ ! -d $outdir || ! -w $outdir ]]; then
  ds_err "cannot write to $outdir"
  exit 1
fi
out="$(cd "$outdir" && pwd)/$(basename "$out")"
tmp="$out.tmp.$$"

stage="$(mktemp -d)"
cleanup() {
  rm -rf "$stage" "$tmp"
  if ((image)); then
    docker image rm dev-sessionizer-sandbox:packed >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT
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

# The sandbox image for another machine: fresh (pulls the base, reinstalls the agents) and
# marked as packed, so `sandbox` on the target never tries to rebuild it.
if ((image)); then
  ds_log "building sandbox image for uid $uid gid $gid ($arch)"
  docker build --pull --no-cache --platform "linux/$arch" \
    --build-arg "UID=$uid" --build-arg "GID=$gid" --build-arg OFFLINE=1 \
    --label dev-sessionizer.packed=1 --label "dev-sessionizer.uid=$uid" \
    --label "dev-sessionizer.gid=$gid" --label "dev-sessionizer.files=$(ds_sandbox_files_hash)" \
    -t dev-sessionizer-sandbox:packed "$DS_ROOT/env/.config/sandbox" >&2 ||
    die "sandbox image build failed"
  save=(save)
  help="$(docker save --help 2>&1 || true)"
  case $help in *--platform*) save+=(--platform "linux/$arch") ;; esac
  docker "${save[@]}" -o "$dest/sandbox-image.tar" dev-sessionizer-sandbox:packed ||
    die "saving the sandbox image failed"
  printf 'sandbox_uid=%s\nsandbox_gid=%s\nsandbox_arch=%s\n' "$uid" "$gid" "$arch" >>"$dest/MANIFEST"
  ds_log "sandbox image for uid $uid gid $gid ($arch) included"
fi

tar -czf "$tmp" -C "$stage" dev-sessionizer || die "writing $out failed"
mv "$tmp" "$out"
ds_log "packed $out"
