#!/usr/bin/env bash
# Verification entry point: tests/verify.sh [lint|mac|linux|all]
set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$PWD"
FAILED=0

usage() {
  cat <<'EOF'
Usage: tests/verify.sh [lint|mac|linux|all]

  lint   bash -n, shellcheck, portability and network gates on every shipped script
  mac    smoke test natively on macOS, entry scripts under /bin/bash (3.2)
  linux  smoke test in a Debian container (unpack step without network)
  all    lint, linux, mac (default)
EOF
}

pass() { printf 'PASS %s\n' "$1"; }
fail() { printf 'FAIL %s: %s\n' "$1" "$2"; FAILED=1; }

shipped_scripts() {
  local f
  for f in install.sh pack.sh unpack.sh lib.sh tests/*.sh \
    env/.config/bash/dev-sessionizer.bash env/.bashrc.example; do
    [[ -f $f ]] && printf '%s\n' "$f"
  done
  for f in env/.config/bin/*; do
    [[ -f $f ]] && head -n 1 "$f" | grep -Eq '^#!.*(ba)?sh' && printf '%s\n' "$f"
  done
  find env/.config/oh-my-bash/custom -type f -name '*.sh' | LC_ALL=C sort
}

# One-platform or bash>=4 constructs that break on macOS (bash 3.2, BSD tools) or Linux.
PORTABILITY_RE='sed -i|readlink -f|date -d|realpath|grep -P|mapfile|readarray|declare -A|declare -n|\$\{[A-Za-z_][A-Za-z0-9_]*(\[[^]]*\])?(,|\^)|&>>|;;?&([^&]|$)' # portable-ok
NETWORK_RE='curl|wget|git (clone|fetch|pull|submodule update)' # portable-ok

run_shellcheck() {
  if command -v shellcheck >/dev/null 2>&1; then
    shellcheck -s bash -S warning -f gcc "$@"
  else
    docker pull -q koalaman/shellcheck-alpine:stable >/dev/null
    docker run --rm -v "$ROOT:/mnt" -w /mnt koalaman/shellcheck-alpine:stable \
      shellcheck -s bash -S warning -f gcc "$@"
  fi
}

target_lint() {
  local problems="$DS_TMP/lint" f
  local files=()
  : >"$problems"
  while IFS= read -r f; do files+=("$f"); done < <(shipped_scripts)

  for f in "${files[@]}"; do
    bash -n "$f" 2>>"$problems" || true
  done

  run_shellcheck "${files[@]}" >>"$problems" 2>&1 || true

  grep -nHE "$PORTABILITY_RE" "${files[@]}" | grep -v '# portable-ok' |
    sed 's/$/  [portability]/' >>"$problems" || true

  for f in install.sh pack.sh unpack.sh lib.sh; do
    [[ -f $f ]] || continue
    grep -nHE "$NETWORK_RE" "$f" |
      grep -vE '^[^:]+:[0-9]+:[[:space:]]*(echo|printf|ds_log|ds_err)[[:space:]]' |
      grep -v '# portable-ok' | sed 's/$/  [network]/' >>"$problems" || true
  done

  if [[ -s $problems ]]; then
    sed 's/^/  /' "$problems"
    fail lint "$(head -n 1 "$problems")"
  else
    pass lint
  fi
}

target_linux() {
  if ! command -v docker >/dev/null 2>&1; then
    fail linux "docker not found"
    return
  fi
  if ! docker build -q -t ds-verify -f tests/Dockerfile . >"$DS_TMP/build" 2>&1; then
    sed 's/^/  /' "$DS_TMP/build"
    fail linux "docker build failed"
    return
  fi
  if ! docker run --rm -v "$ROOT:/src:ro" ds-verify bash tests/smoke.sh >"$DS_TMP/linux" 2>&1; then
    sed 's/^/  /' "$DS_TMP/linux"
    fail linux "$(grep -m 1 '^not ok' "$DS_TMP/linux" || echo 'smoke test failed')"
    return
  fi

  # Offline unpack: pack in one container, unpack in a second one with no network (SC-004).
  local shared="$DS_TMP/archive"
  mkdir -p "$shared"
  chmod 777 "$shared"
  if ! docker run --rm -v "$ROOT:/src:ro" -v "$shared:/out" ds-verify bash -c '
      set -e; export HOME="$(mktemp -d)"
      ./install.sh >/dev/null
      mkdir -p ~/.local/share/nvim && echo offline >~/.local/share/nvim/marker
      ./pack.sh /out/ds.tar.gz >/dev/null' >"$DS_TMP/pack" 2>&1; then
    sed 's/^/  /' "$DS_TMP/pack"
    fail linux "pack for offline unpack failed"
    return
  fi
  if docker run --rm --network none -v "$shared:/in:ro" ds-verify bash -c '
      set -e; export HOME="$(mktemp -d)"; cd "$(mktemp -d)"
      tar -xzf /in/ds.tar.gz
      bash dev-sessionizer/unpack.sh >/dev/null
      test "$(cat ~/.local/share/nvim/marker)" = offline
      test -z "$(nvim --headless +qa 2>&1)"' >"$DS_TMP/offline" 2>&1; then
    pass linux
  else
    sed 's/^/  /' "$DS_TMP/offline"
    fail linux "unpack without network failed"
  fi
}

target_mac() {
  if [[ $(uname -s) != Darwin ]]; then
    printf 'SKIP mac\n'
    return
  fi
  if DS_BASH=/bin/bash /bin/bash tests/smoke.sh >"$DS_TMP/mac" 2>&1; then
    pass mac
  else
    sed 's/^/  /' "$DS_TMP/mac"
    fail mac "$(grep -m 1 '^not ok' "$DS_TMP/mac" || echo 'smoke test failed')"
  fi
}

DS_TMP="$(mktemp -d)"
trap 'rm -rf "$DS_TMP"' EXIT

case "${1:-all}" in
  lint) target_lint ;;
  mac) target_mac ;;
  linux) target_linux ;;
  all) target_lint; target_linux; target_mac ;;
  -h | --help) usage; exit 0 ;;
  *) usage >&2; exit 2 ;;
esac

exit "$FAILED"
