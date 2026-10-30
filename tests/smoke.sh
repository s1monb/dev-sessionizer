#!/usr/bin/env bash
# Smoke scenarios, each run in its own throwaway $HOME: tests/smoke.sh [scenario_name...]
# The harness and the entry scripts must stay compatible with bash 3.2.
set -euo pipefail

cd "$(dirname "$0")/.."
REPO="$PWD"

DS_REAL_HOME="$HOME"
DS_RUN="$(mktemp -d)"
DS_BASH="${DS_BASH:-bash}"
export DS_SANDBOX=1 DS_REAL_HOME DS_BASH
trap 'rm -rf "$DS_RUN"' EXIT

# Keep tools away from the real environment: XDG paths, a running tmux, the user's nvim app name,
# and PATH entries under the real home (an installed ~/.config/bin would shadow the sandbox's).
unset XDG_CONFIG_HOME XDG_DATA_HOME XDG_STATE_HOME XDG_CACHE_HOME NVIM_APPNAME TMUX TMUX_PANE
__path=""
IFS=: read -r -a __entries <<<"$PATH"
for __e in ${__entries[@]+"${__entries[@]}"}; do
  case "$__e" in "$DS_REAL_HOME" | "$DS_REAL_HOME"/*) ;; *) __path="${__path:+$__path:}$__e" ;; esac
done
export PATH="$__path"
unset __path __entries __e

# shellcheck source=../lib.sh
source "$REPO/lib.sh"

new_sandbox() {
  HOME="$(mktemp -d "$DS_RUN/home.XXXXXX")"
  export HOME TMUX_TMPDIR="$HOME"
  ds_guard_sandbox_home
}

# Asserts print "ok"/"not ok" and exit the scenario's subshell on failure.
assert_ok() {
  local desc="$1"
  shift
  if "$@" >"$DS_RUN/out" 2>"$DS_RUN/err"; then
    printf 'ok %s\n' "$desc"
  else
    printf 'not ok %s\n' "$desc"
    sed 's/^/    /' "$DS_RUN/out" "$DS_RUN/err"
    exit 1
  fi
}

assert_fail() {
  local desc="$1"
  shift
  if "$@" >"$DS_RUN/out" 2>"$DS_RUN/err"; then
    printf 'not ok %s (expected failure)\n' "$desc"
    exit 1
  fi
  printf 'ok %s\n' "$desc"
}

assert_eq() {
  if [[ $2 == "$3" ]]; then
    printf 'ok %s\n' "$1"
  else
    printf 'not ok %s\n    expected: %s\n    actual:   %s\n' "$1" "$3" "$2"
    exit 1
  fi
}

assert_contains() {
  case "$2" in
    *"$3"*) printf 'ok %s\n' "$1" ;;
    *)
      printf 'not ok %s\n    missing %s in:\n' "$1" "$3"
      printf '%s\n' "$2" | sed 's/^/    /'
      exit 1
      ;;
  esac
}

assert_not_contains() {
  case "$2" in
    *"$3"*)
      printf 'not ok %s\n    unexpected %s in:\n' "$1" "$3"
      printf '%s\n' "$2" | grep -F -- "$3" | head -n 5 | sed 's/^/    /'
      exit 1
      ;;
    *) printf 'ok %s\n' "$1" ;;
  esac
}

checksum_tree() {
  (cd "$1" && find . -type f -exec cksum {} + | LC_ALL=C sort)
}

checksum_managed() {
  local p
  while IFS= read -r p; do
    if [[ -d $p ]]; then checksum_tree "$p"; elif [[ -f $p ]]; then cksum <"$p"; fi
  done < <(ds_managed)
}

install() { "$DS_BASH" "$REPO/install.sh"; }

# --- US1 -------------------------------------------------------------------

scenario_harness_sandbox() {
  new_sandbox
  assert_ok "sandbox home differs from the real home" test "$HOME" != "$DS_REAL_HOME"
  if [[ $(uname -s) == Darwin && $DS_BASH == /bin/bash ]]; then
    assert_contains "entry scripts run under bash 3.2" "$("$DS_BASH" --version)" "version 3.2"
  fi
}

# --- US2: install / update -------------------------------------------------

scenario_install_idempotent() {
  new_sandbox
  local first second third
  install >/dev/null
  first="$(checksum_managed)"
  install >/dev/null
  second="$(checksum_managed)"
  install >/dev/null
  third="$(checksum_managed)"
  assert_ok "managed paths are populated" test -n "$first"
  assert_eq "second install leaves managed paths identical" "$second" "$first"
  assert_eq "third install leaves managed paths identical" "$third" "$first"
}

scenario_missing_prereq_writes_nothing() {
  new_sandbox
  local tmpbin="$DS_RUN/bin-no-tmux" tool err
  mkdir -p "$tmpbin"
  for tool in bash git nvim fzf tar find env dirname basename uname cp rm mkdir cat sort cksum grep; do
    ln -sf "$(command -v "$tool")" "$tmpbin/$tool"
  done
  assert_fail "install fails without tmux" env PATH="$tmpbin" "$(command -v "$DS_BASH")" "$REPO/install.sh"
  err="$(cat "$DS_RUN/err")"
  assert_contains "error names what is missing" "$err" "missing: tmux"
  assert_not_contains "no utility is missing from the test PATH" "$err" "command not found"
  assert_eq "nothing was written to HOME" "$(find "$HOME" -mindepth 1 | wc -l | tr -d ' ')" "0"
}

scenario_components_load() {
  new_sandbox
  install >/dev/null
  assert_eq "interactive bash loads the shared setup" \
    "$(bash -ic 'printf "%s|%s" "$OSH_THEME" "$(type -t jwt-decode)"' 2>/dev/null)" "dev-sessionizer|function"
  assert_eq "neovim starts without errors" "$(nvim --headless +qa 2>&1)" ""
  assert_ok "enabled language servers resolve from vendored nvim-lspconfig" nvim --headless \
    "+lua for _, s in ipairs({'lua_ls','rust_analyzer','tinymist','marksman','ts_ls'}) do assert(vim.lsp.config[s], s) end" +qa
  assert_ok "tmux config loads" tmux -L ds-verify -f /dev/null new-session -d 'sleep 30' \; \
    source-file "$HOME/.config/tmux/tmux.conf"
  tmux -L ds-verify kill-server 2>/dev/null || true
  assert_ok "dev is installed and executable" test -x "$HOME/.config/bin/dev"
}

scenario_install_time() {
  new_sandbox
  SECONDS=0
  install >/dev/null
  assert_ok "install finishes in under 120 s (took ${SECONDS}s)" test "$SECONDS" -lt 120
}

# --- US3: overrides --------------------------------------------------------

scenario_overrides_survive_and_load() {
  new_sandbox
  install >/dev/null
  local L="$HOME/.config/local" before after
  echo 'vim.g.local_marker = 1' >>"$L/nvim.lua"
  echo 'set -g @local_marker 1' >>"$L/tmux.conf"
  printf '#!/usr/bin/env bash\necho local-dev\n' >"$L/bin/dev"
  chmod +x "$L/bin/dev"
  echo 'export DS_LOCAL_MARKER=1' >>"$HOME/.bashrc"
  before="$(cksum "$L/nvim.lua" "$L/tmux.conf" "$L/bin/dev" "$HOME/.bashrc")"

  install >/dev/null
  after="$(cksum "$L/nvim.lua" "$L/tmux.conf" "$L/bin/dev" "$HOME/.bashrc")"
  assert_eq "install leaves every override file unchanged" "$after" "$before"

  assert_eq "neovim loads the local override" \
    "$(nvim --headless -c 'lua io.stdout:write(tostring(vim.g.local_marker))' -c qa 2>&1)" "1"
  assert_eq "tmux loads the local override" \
    "$(tmux -L ds-verify -f /dev/null new-session -d 'sleep 30' \; source-file "$HOME/.config/tmux/tmux.conf" \; show -gv @local_marker)" "1"
  tmux -L ds-verify kill-server 2>/dev/null || true
  assert_eq "local scripts win on PATH and ~/.bashrc runs after the shared setup" \
    "$(bash -ic 'dev; echo "$DS_LOCAL_MARKER"' 2>/dev/null)" "local-dev"$'\n'"1"
}

# --- US4: pack / unpack ----------------------------------------------------

# Extracts archive $1 into a fresh folder and prints the path of its dev-sessionizer/ dir.
extract() {
  local d
  d="$(mktemp -d "$DS_RUN/x.XXXXXX")"
  tar -xzf "$1" -C "$d"
  printf '%s' "$d/dev-sessionizer"
}

# Installs and creates runtime state with markers, then packs it to $1.
pack_with_state() {
  install >/dev/null
  mkdir -p "$HOME/.local/share/nvim" "$HOME/.local/state/nvim"
  echo share >"$HOME/.local/share/nvim/marker"
  echo state >"$HOME/.local/state/nvim/marker"
  "$DS_BASH" "$REPO/pack.sh" "$1" >/dev/null
}

scenario_pack_without_runtime_state() {
  new_sandbox
  local archive="$DS_RUN/empty.tar.gz" listing
  mkdir -p "$DS_RUN/tmp-pack"
  assert_ok "pack succeeds with no runtime state" env TMPDIR="$DS_RUN/tmp-pack" "$DS_BASH" "$REPO/pack.sh" "$archive"
  listing="$(tar -tzf "$archive")"
  assert_contains "archive has a MANIFEST" "$listing" "dev-sessionizer/MANIFEST"
  assert_contains "archive carries its own unpack script" "$listing" "dev-sessionizer/unpack.sh"
  assert_not_contains "archive has no runtime folder" "$listing" "dev-sessionizer/runtime/"
  assert_eq "archive has no .git entries" "$(printf '%s\n' "$listing" | grep -cE '/\.git/?$' || true)" "0"
  assert_eq "pack leaves no temporary files" "$(find "$DS_RUN/tmp-pack" -mindepth 1 | wc -l | tr -d ' ')" "0"
}

scenario_pack_unpack_roundtrip() {
  new_sandbox
  local archive="$DS_RUN/roundtrip.tar.gz" dir
  pack_with_state "$archive"
  assert_not_contains "archive excludes installed plugin copies" "$(tar -tzf "$archive")" "runtime/share/nvim/site/pack/vendor"

  new_sandbox
  mkdir -p "$HOME/.config/local" "$HOME/.local/share/nvim"
  echo "-- keep" >"$HOME/.config/local/nvim.lua"
  echo old >"$HOME/.local/share/nvim/stale"
  dir="$(extract "$archive")"
  assert_ok "unpack succeeds" "$DS_BASH" "$dir/unpack.sh"
  assert_eq "share runtime state is restored" "$(cat "$HOME/.local/share/nvim/marker")" "share"
  assert_eq "state runtime state is restored" "$(cat "$HOME/.local/state/nvim/marker")" "state"
  assert_ok "stale runtime state on the target is replaced" test ! -e "$HOME/.local/share/nvim/stale"
  assert_eq "override file is untouched" "$(cat "$HOME/.config/local/nvim.lua")" "-- keep"
  assert_ok "plugins come from install" test -d "$HOME/.local/share/nvim/site/pack/vendor/start/blink.cmp"
  assert_eq "neovim starts without errors after unpack" "$(nvim --headless +qa 2>&1)" ""
}

scenario_unpack_platform_mismatch() {
  new_sandbox
  local archive="$DS_RUN/mismatch.tar.gz" dir err
  pack_with_state "$archive"

  new_sandbox
  dir="$(extract "$archive")"
  printf 'os=%s\narch=bogus\ncreated=test\n' "$(ds_os)" >"$dir/MANIFEST"
  assert_ok "unpack still succeeds" "$DS_BASH" "$dir/unpack.sh"
  err="$(cat "$DS_RUN/err")"
  assert_contains "mismatch is reported" "$err" "runtime state from $(ds_os)/bogus skipped on $(ds_os)/$(ds_arch)"
  assert_ok "runtime state is not restored" test ! -e "$HOME/.local/share/nvim/marker"
  assert_ok "environment is still installed" test -f "$HOME/.config/nvim/init.lua"
}

# --- US5: project sessions -------------------------------------------------

dev() { "$DS_BASH" "$HOME/.config/bin/dev" "$@"; }

scenario_dev_sessions() {
  new_sandbox
  install >/dev/null
  mkdir -p "$HOME/p/a.b c/.git" "$HOME/q/a.b c/.git"
  export DS_DEV_NO_ATTACH=1
  assert_ok "dev opens a session for a path" dev "$HOME/p/a.b c"
  assert_eq "session name is sanitised" "$(tmux ls -F '#S')" "a_b_c"
  assert_ok "dev on the same path again succeeds" dev "$HOME/p/a.b c"
  assert_eq "no duplicate session" "$(tmux ls -F '#S' | wc -l | tr -d ' ')" "1"
  assert_ok "dev on a same-named project elsewhere succeeds" dev "$HOME/q/a.b c"
  assert_eq "colliding name gets the parent folder" "$(tmux ls -F '#S' | LC_ALL=C sort | tr '\n' ' ')" "a_b_c a_b_c_q "
  tmux kill-server 2>/dev/null || true
}

scenario_dev_roots_file() {
  new_sandbox
  install >/dev/null
  mkdir -p "$HOME/p/one/.git" "$HOME/q/two/.git" "$HOME/p/one/nested/.git"
  # shellcheck disable=SC2016,SC2088  # literal ~ and $VAR text is the point: dev expands it, never evaluates it
  printf '%s\n' '# comment' '' '~/p' '$HOME/q' '${HOME}/missing' '$(touch $HOME/pwned)' >"$HOME/.devconfig"
  assert_eq "lists the repos under every existing root" \
    "$(dev --list | LC_ALL=C sort | tr '\n' ' ')" "$HOME/p/one $HOME/q/two "
  assert_ok "nothing in the roots file is executed" test ! -e "$HOME/pwned"
  rm "$HOME/.devconfig"
  assert_fail "missing roots file is an error" dev --list
  assert_contains "error names the roots file" "$(cat "$DS_RUN/err")" ".devconfig"
}

scenario_dev_list_200() {
  new_sandbox
  install >/dev/null
  local i
  for i in $(seq 1 100); do mkdir -p "$HOME/r1/repo$i/.git" "$HOME/r2/repo$i/.git"; done
  # shellcheck disable=SC2088  # dev expands the literal ~ itself
  printf '%s\n' '~/r1' '~/r2' >"$HOME/.devconfig"
  SECONDS=0
  assert_eq "lists all 200 repos" "$(dev --list | wc -l | tr -d ' ')" "200"
  assert_ok "listing 200 repos takes under 3 s (took ${SECONDS}s)" test "$SECONDS" -lt 3
}

# --- US6: helpers ----------------------------------------------------------

scenario_helpers() {
  new_sandbox
  install >/dev/null
  local bin="$HOME/.config/bin"
  assert_fail "esc-caps-swap refuses to run outside GNOME" env -u XDG_CURRENT_DESKTOP "$DS_BASH" "$bin/esc-caps-swap"
  assert_contains "esc-caps-swap explains why" "$(cat "$DS_RUN/err")" "requires GNOME (gsettings)"
  assert_fail "dev-gc without arguments fails" "$DS_BASH" "$bin/dev-gc"
  assert_contains "dev-gc prints its usage" "$(cat "$DS_RUN/out")" "Usage"
  assert_eq "only the supported helpers are installed" "$(ls "$bin" | tr '\n' ' ')" "dev dev-gc esc-caps-swap "
  assert_ok "the AI runner is not installed" test ! -e "$HOME/.config/ai"
  assert_eq "no trace of the removed helpers" \
    "$(grep -rlE 'kubectx-create|claude-session|config/ai|alias ifi' "$HOME/.config" "$HOME/.bashrc" 2>/dev/null || true)" ""
}

# --- runner ----------------------------------------------------------------

scenarios=()
if (($# > 0)); then
  scenarios=("$@")
else
  while read -r _ _ name; do
    case "$name" in scenario_*) scenarios+=("$name") ;; esac
  done < <(declare -F)
fi

failed=0
for s in ${scenarios[@]+"${scenarios[@]}"}; do
  printf '# %s\n' "$s"
  if ! ("$s"); then
    failed=$((failed + 1))
  fi
done

printf '# %d scenario(s), %d failed\n' "${#scenarios[@]}" "$failed"
((failed == 0))
