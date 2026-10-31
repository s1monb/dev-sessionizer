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

# Milliseconds since the epoch. GNU date has %N; macOS date does not, so fall back to perl.
now_ms() {
  local ns
  ns="$(date +%s%N)"
  if [[ $ns =~ ^[0-9]+$ ]]; then
    printf '%s\n' "$((ns / 1000000))"
  else
    perl -MTime::HiRes=time -e 'printf "%d\n", time * 1000'
  fi
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
  assert_eq "every leader keymap has a description for which-key" "$(nvim --headless \
    "+lua require('which-key'); for _, m in ipairs(vim.api.nvim_get_keymap('n')) do if m.lhs:sub(1, 1) == ' ' and (m.desc or '') == '' then io.write(m.lhs, ' ') end end" \
    +qa 2>&1)" ""
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
  mkdir -p "$HOME/p/one/.git" "$HOME/q/two/.git" "$HOME/p/one/nested/.git" \
    "$HOME/p/a/b/three/.git" "$HOME/p/a/b/c/four/.git" "$HOME/p/.hidden/five/.git" "$HOME/p/wt"
  printf 'gitdir: x\n' >"$HOME/p/wt/.git"
  ln -s "$HOME/q" "$HOME/p/link"
  # shellcheck disable=SC2016,SC2088  # literal ~ and $VAR text is the point: dev expands it, never evaluates it
  printf '%s\n' '# comment' '' '~/p' '$HOME/q' '${HOME}/missing' '$(touch $HOME/pwned)' >"$HOME/.devconfig"
  assert_eq "lists repos up to 3 deep under every existing root, skipping links and nested repos" \
    "$(dev --list | LC_ALL=C sort | tr '\n' ' ')" \
    "$HOME/p/.hidden/five $HOME/p/a/b/three $HOME/p/one $HOME/p/wt $HOME/q/two "
  assert_ok "nothing in the roots file is executed" test ! -e "$HOME/pwned"
  rm "$HOME/.devconfig"
  assert_fail "missing roots file is an error" dev --list
  assert_contains "error names the roots file" "$(cat "$DS_RUN/err")" ".devconfig"
}

scenario_dev_list_200() {
  new_sandbox
  install >/dev/null
  local i start out ms
  for i in $(seq 1 100); do mkdir -p "$HOME/r1/repo$i/.git" "$HOME/r2/repo$i/.git"; done
  # A non-repo tree of 5,000 folders next to the repos.
  for i in $(seq 1 20); do mkdir -p "$HOME/r1/big/a$i"/b{1..25}/c{1..10}; done
  # shellcheck disable=SC2088  # dev expands the literal ~ itself
  printf '%s\n' '~/r1' '~/r2' >"$HOME/.devconfig"
  start="$(now_ms)"
  out="$(dev --list)"
  ms=$(($(now_ms) - start))
  assert_eq "lists all 200 repos" "$(printf '%s\n' "$out" | wc -l | tr -d ' ')" "200"
  assert_ok "listing 200 repos next to 5,000 folders takes under 1 s (took ${ms} ms)" test "$ms" -lt 1000
}

scenario_dev_depth_cost() {
  new_sandbox
  install >/dev/null
  local i before start after ms
  for i in $(seq 1 20); do mkdir -p "$HOME/r/org/repo$i/.git"; done
  mkdir -p "$HOME/r/org/data"
  # shellcheck disable=SC2088  # dev expands the literal ~ itself
  printf '%s\n' '~/r' >"$HOME/.devconfig"
  before="$(dev --list)"
  # 10,000 folders, all deeper than the default depth of 3.
  for i in $(seq 1 100); do mkdir -p "$HOME/r/org/data/x/a$i"/b{1..100}; done
  start="$(now_ms)"
  after="$(dev --list)"
  ms=$(($(now_ms) - start))
  assert_eq "folders below the depth do not change the list" "$after" "$before"
  assert_ok "folders below the depth do not slow the list (took ${ms} ms)" test "$ms" -lt 1000
}

scenario_dev_root_depth() {
  new_sandbox
  install >/dev/null
  local bad
  mkdir -p "$HOME/p/a/b/c/four/.git" "$HOME/q/a/b/c/four/.git" "$HOME/My Projects/x/.git" \
    "$HOME/a:b/c/r/.git"
  # shellcheck disable=SC2016,SC2088  # literal ~ and $VAR text is the point: dev expands it, never evaluates it
  printf '%s\n' '~/p:4' '~/q' '$HOME/My Projects:1' >"$HOME/.devconfig"
  assert_eq "a root's :N sets its depth; other roots keep the default" \
    "$(dev --list | LC_ALL=C sort | tr '\n' '|')" "$HOME/My Projects/x|$HOME/p/a/b/c/four|"
  # shellcheck disable=SC2088
  printf '%s\n' '~/a:b/c' >"$HOME/.devconfig"
  assert_eq "a colon followed by a slash is part of the path" "$(dev --list)" "$HOME/a:b/c/r"
  # shellcheck disable=SC2016
  printf '%s\n' '$(touch $HOME/pwned):2' >"$HOME/.devconfig"
  assert_ok "a line with a depth is never executed" dev --list
  assert_ok "nothing was executed" test ! -e "$HOME/pwned"

  for bad in 0 deep ''; do
    # shellcheck disable=SC2088
    printf '%s\n' '# roots' '~/q' "~/p:$bad" >"$HOME/.devconfig"
    assert_fail "bad depth '$bad' is an error" dev --list
    assert_contains "error names the line" "$(cat "$DS_RUN/err")" ".devconfig line 3"
    assert_contains "error names the value" "$(cat "$DS_RUN/err")" "'$bad'"
    assert_eq "bad depth prints nothing" "$(cat "$DS_RUN/out")" ""
  done

  # The picker checks the roots file before fzf starts.
  mkdir -p "$HOME/stub"
  printf '#!/bin/sh\ntouch "$HOME/fzf-ran"\ncat >/dev/null\n' >"$HOME/stub/fzf"
  chmod +x "$HOME/stub/fzf"
  # shellcheck disable=SC2088
  printf '%s\n' '# roots' '~/q' '~/p:deep' >"$HOME/.devconfig"
  PATH="$HOME/stub:$PATH" assert_fail "picker fails on a bad depth" dev
  assert_contains "picker error names the line" "$(cat "$DS_RUN/err")" ".devconfig line 3"
  assert_ok "picker never started fzf" test ! -e "$HOME/fzf-ran"
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
  assert_eq "only the supported helpers are installed" "$(ls "$bin" | tr '\n' ' ')" "dev dev-gc esc-caps-swap sandbox "
  assert_ok "the AI runner is not installed" test ! -e "$HOME/.config/ai"
  assert_eq "no trace of the removed helpers" \
    "$(grep -rlE 'kubectx-create|claude-session|config/ai|alias ifi' "$HOME/.config" "$HOME/.bashrc" 2>/dev/null || true)" ""
}

# --- agent sandbox ---------------------------------------------------------

# Docker scenarios need the host engine and network; verify.sh sandbox sets DS_DOCKER_TESTS=1.
needs_docker() {
  if [[ ${DS_DOCKER_TESTS:-} != 1 ]]; then
    printf 'ok # skip (DS_DOCKER_TESTS=1 to run)\n'
    return 1
  fi
  # The throwaway HOME has no Docker config; keep the real context and CLI plugins.
  export DOCKER_CONFIG="$DS_REAL_HOME/.docker"
}

sandbox_cmd() { "$DS_BASH" "$HOME/.config/bin/sandbox" "$@"; }

# A git repo with one commit; prints its physical path.
new_project() {
  local dir
  dir="$(mktemp -d "$HOME/proj.XXXXXX")"
  git -C "$dir" init -q
  git -C "$dir" -c user.name=t -c user.email=t@example.com commit -q --allow-empty -m init
  (cd "$dir" && pwd -P)
}

drop_cache() {
  local v
  for v in $(docker volume ls -q --filter "label=dev-sessionizer.project=$1"); do
    docker volume rm -f "$v" >/dev/null
  done
}

scenario_sandbox_install() {
  new_sandbox
  install >/dev/null
  local env="$HOME/.config/local/sandbox.env"
  assert_ok "sandbox is installed" test -x "$HOME/.config/bin/sandbox"
  assert_ok "image files are installed" test -f "$HOME/.config/sandbox/Dockerfile" -a -x "$HOME/.config/sandbox/entrypoint.sh"
  assert_contains "sandbox.env is private" "$(ls -l "$env")" "-rw-------"
  echo 'MINE=1' >>"$env"
  install >/dev/null
  assert_contains "install keeps sandbox.env" "$(cat "$env")" "MINE=1"
}

scenario_sandbox_refusals() {
  new_sandbox
  install >/dev/null
  mkdir -p "$HOME/p"
  local arg
  for arg in "$HOME" / "$(dirname "$HOME")" "$HOME/missing" --bogus; do
    assert_fail "sandbox refuses $arg" sandbox_cmd "$arg"
    assert_contains "refusal of $arg is explained" "$(cat "$DS_RUN/err")" "sandbox:"
  done
  assert_fail "sandbox refuses an unknown agent" sandbox_cmd codex
  assert_contains "unknown agent lists the agents" "$(cat "$DS_RUN/err")" "claude, opencode, shell"
  assert_fail "sandbox refuses two folders" sandbox_cmd "$HOME/p" "$HOME/p"
  assert_ok "sandbox --help succeeds" sandbox_cmd --help
  assert_contains "help shows usage" "$(cat "$DS_RUN/out")" "Usage"
  if [[ -e /usr/bin/docker || -e /bin/docker ]]; then
    printf 'ok # skip docker not found (docker is in /usr/bin or /bin)\n'
  else
    assert_fail "sandbox without docker fails" env PATH=/usr/bin:/bin "$DS_BASH" "$HOME/.config/bin/sandbox" "$HOME/p"
    assert_contains "missing docker is explained" "$(cat "$DS_RUN/err")" "docker not found"
  fi
}

scenario_agent_isolation() {
  needs_docker || return 0
  new_sandbox
  install >/dev/null
  git config --global user.name "Sandbox Tester"
  git config --global user.email "tester@example.com"
  local proj out
  proj="$(new_project)"
  export SSH_AUTH_SOCK=/tmp/fake.sock
  out="$(sandbox_cmd shell "$proj" -- -c '
    echo "uid=$(id -u) gid=$(id -g) pwd=$PWD"
    grep -E "CapEff|NoNewPrivs" /proc/self/status
    command -v sudo || echo no-sudo
    ls /var/run/docker.sock /run/docker.sock 2>/dev/null || echo no-docker-socket
    echo "ssh=${SSH_AUTH_SOCK:-unset}"
    touch /etc/x 2>/dev/null || echo etc-denied
    touch "$(dirname "$PWD")/outside" 2>/dev/null || echo outside-denied
    claude --version >/dev/null && echo claude-ok
    echo hi >made && git add made && git commit -qm sbx && echo committed
    git push -q https://github.com/s1monb/dev-sessionizer.git HEAD:refs/heads/sbx-test 2>/dev/null || echo push-denied
  ' 2>&1)"
  assert_contains "runs as the host user in the project" "$out" "uid=$(id -u) gid=$(id -g) pwd=$proj"
  assert_contains "no capabilities" "$out" "CapEff:	0000000000000000"
  assert_contains "no new privileges" "$out" "NoNewPrivs:	1"
  assert_contains "no sudo" "$out" "no-sudo"
  assert_contains "no docker socket" "$out" "no-docker-socket"
  assert_contains "no ssh agent" "$out" "ssh=unset"
  assert_contains "system folders are read-only" "$out" "etc-denied"
  assert_contains "host outside the project is unreachable" "$out" "outside-denied"
  assert_contains "claude is installed" "$out" "claude-ok"
  assert_contains "commits work" "$out" "committed"
  assert_contains "push is denied" "$out" "push-denied"
  assert_ok "nothing appeared outside the project" test ! -e "$(dirname "$proj")/outside"
  assert_contains "created files belong to the host user" "$(ls -ln "$proj/made")" " $(id -u) "
  assert_eq "commit carries the host identity" "$(git -C "$proj" log -1 --format=%an)" "Sandbox Tester"
  assert_eq "the container is gone" "$(docker ps -aq --filter ancestor=dev-sessionizer-sandbox)" ""
  drop_cache "$proj"
}

scenario_agent_config() {
  needs_docker || return 0
  new_sandbox
  install >/dev/null
  local proj out before after
  proj="$(new_project)"
  mkdir -p ~/.claude/projects/p ~/.config/opencode/node_modules/x ~/.local/share/opencode
  echo '{"marker":1}' >~/.claude/settings.json
  echo MARKER-CLAUDE >~/.claude/CLAUDE.md
  echo '{}' >~/.claude/projects/p/t.jsonl
  echo '{}' >~/.claude/history.jsonl
  echo '{}' >~/.claude/.credentials.json
  echo '{"hasCompletedOnboarding":true}' >~/.claude.json
  echo '{}' >~/.config/opencode/opencode.jsonc
  echo '//' >~/.config/opencode/node_modules/x/index.js
  echo '{}' >~/.local/share/opencode/auth.json
  echo FROM_ENVFILE=yes >>~/.config/local/sandbox.env
  before="$(checksum_tree ~/.claude; cksum <~/.claude.json; checksum_tree ~/.config/opencode; cksum <~/.local/share/opencode/auth.json)"
  out="$(CLAUDE_CODE_OAUTH_TOKEN=tok UNRELATED_SECRET=nope sandbox_cmd shell "$proj" -- -c '
    cat ~/.claude/CLAUDE.md
    for f in ~/.claude.json ~/.config/opencode/opencode.jsonc ~/.local/share/opencode/auth.json; do
      test -f "$f" && echo "present ${f#$HOME/}"
    done
    for f in ~/.claude/projects ~/.claude/history.jsonl ~/.claude/.credentials.json ~/.config/opencode/node_modules; do
      test -e "$f" && echo "leaked ${f#$HOME/}"
    done
    echo "{}" >~/.claude/settings.json && echo copy-writable
    echo x >>/host/claude/settings.json 2>/dev/null || echo host-readonly
    echo "token=$CLAUDE_CODE_OAUTH_TOKEN envfile=$FROM_ENVFILE unrelated=${UNRELATED_SECRET:-unset}"
  ' 2>&1)"
  after="$(checksum_tree ~/.claude; cksum <~/.claude.json; checksum_tree ~/.config/opencode; cksum <~/.local/share/opencode/auth.json)"
  assert_contains "global instructions are inherited" "$out" "MARKER-CLAUDE"
  assert_contains "claude.json is inherited" "$out" "present .claude.json"
  assert_contains "opencode config is inherited" "$out" "present .config/opencode/opencode.jsonc"
  assert_contains "opencode login is inherited" "$out" "present .local/share/opencode/auth.json"
  assert_not_contains "history and credentials stay out" "$out" "leaked"
  assert_contains "the agent can change its copy" "$out" "copy-writable"
  assert_contains "the host config is read-only" "$out" "host-readonly"
  assert_contains "only listed variables cross over" "$out" "token=tok envfile=yes unrelated=unset"
  assert_eq "host config is unchanged" "$after" "$before"
  rm -rf ~/.claude ~/.claude.json ~/.config/opencode ~/.local/share/opencode
  assert_ok "starts without any host config" sandbox_cmd shell "$proj" -- -c true
  drop_cache "$proj"
}

scenario_agent_opencode() {
  needs_docker || return 0
  new_sandbox
  install >/dev/null
  local proj
  proj="$(new_project)"
  assert_ok "opencode runs in the sandbox" sandbox_cmd opencode "$proj" -- --version
  assert_contains "opencode can skip permission prompts" \
    "$(sandbox_cmd shell "$proj" -- -c 'opencode --help 2>&1')" "--auto"
  drop_cache "$proj"
}

scenario_agent_cache() {
  needs_docker || return 0
  new_sandbox
  install >/dev/null
  local proj other broken
  proj="$(new_project)"
  other="$(new_project)"
  broken="$(new_project)"
  echo 'shfmt 3.10.0' >"$proj/.tool-versions"
  echo 'shfmt 3.10.0' >"$other/.tool-versions"
  echo 'shfmt 0.0.999' >"$broken/.tool-versions"
  assert_contains "project tools are installed" "$(sandbox_cmd shell "$proj" -- -c 'shfmt --version' 2>&1)" "v3.10.0"
  assert_contains "tools are reused without network" \
    "$(sandbox_cmd --network none shell "$proj" -- -c 'shfmt --version' 2>&1)" "v3.10.0"
  assert_fail "another project has its own cache" sandbox_cmd --network none shell "$other" -- -c 'shfmt --version'
  assert_fail "--reset empties the cache" sandbox_cmd --reset --network none shell "$proj" -- -c 'shfmt --version'
  assert_ok "a failing tool install still starts the session" sandbox_cmd shell "$broken" -- -c true
  assert_contains "the failed install is reported" "$(cat "$DS_RUN/err")" "mise install failed"
  drop_cache "$proj"
  drop_cache "$other"
  drop_cache "$broken"
}

scenario_agent_shell() {
  needs_docker || return 0
  new_sandbox
  install >/dev/null
  local proj status=0
  proj="$(new_project)"
  assert_eq "shell runs as agent in the project" \
    "$(sandbox_cmd shell "$proj" -- -c 'echo "$HOME $PWD $(id -un)"')" "/home/agent $proj agent"
  sandbox_cmd shell "$proj" -- -c 'exit 7' || status=$?
  assert_eq "the exit status passes through" "$status" 7
  drop_cache "$proj"
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
