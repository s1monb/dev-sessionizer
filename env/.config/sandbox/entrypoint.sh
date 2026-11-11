#!/usr/bin/env bash
# Entrypoint of the sandbox image: sandbox-entrypoint claude|opencode|shell [ARGS...]
# Runs as the unprivileged agent user in the project folder.
set -euo pipefail

mode="${1:-}"
shift || true

# Host config arrives read-only under /host. Work on copies so the agent can change its settings
# for this session without touching the host. Session history and logins that rotate stay out.
copy_tree() {
  local src="$1" dest="$2"
  shift 2
  [[ -d $src ]] || return 0
  mkdir -p "$dest"
  tar -C "$src" -cf - "$@" . | tar -C "$dest" -xf -
  chmod -R u+w "$dest"
}
copy_file() {
  [[ -f $1 ]] || return 0
  mkdir -p "$(dirname "$2")"
  cp "$1" "$2"
  chmod 600 "$2"
}
copy_tree /host/claude "$HOME/.claude" \
  --exclude=./projects --exclude=./file-history --exclude=./history.jsonl --exclude=./sessions \
  --exclude=./session-env --exclude=./shell-snapshots --exclude=./paste-cache --exclude=./cache \
  --exclude=./backups --exclude=./todos --exclude=./statsig --exclude=./debug --exclude=./ide \
  --exclude=./.credentials.json
copy_file /host/claude.json "$HOME/.claude.json"
copy_tree /host/opencode-config "$HOME/.config/opencode" --exclude=./node_modules
copy_file /host/opencode-auth.json "$HOME/.local/share/opencode/auth.json"

# The sandbox is the isolation Claude Code's bypass-permissions dialog asks for, so pre-accept it
# in this session's copy of the settings (the host file is never touched).
settings="$HOME/.claude/settings.json"
mkdir -p "$HOME/.claude"
[[ -f $settings ]] || echo '{}' >"$settings"
if jq '.skipDangerousModePermissionPrompt = true' "$settings" >"$settings.tmp" 2>/dev/null; then
  mv "$settings.tmp" "$settings"
else
  rm -f "$settings.tmp"
  echo "sandbox: ~/.claude/settings.json is not valid JSON; Claude Code will ask to confirm bypass mode" >&2
fi

# Images packed for an airgapped machine: no model catalog or language server downloads, which
# would only wait on the blocked network. Models come from the target's own OpenCode config.
if [[ ${SANDBOX_OFFLINE:-0} == 1 ]]; then
  export OPENCODE_DISABLE_MODELS_FETCH=1 OPENCODE_DISABLE_LSP_DOWNLOAD=1
fi

# Tools the project pins for mise, installed into the per-project cache under /cache.
if [[ -f mise.toml || -f .mise.toml || -f .tool-versions ]]; then
  export MISE_TRUSTED_CONFIG_PATHS="$PWD"
  mise install --yes >&2 || echo "sandbox: mise install failed; starting anyway" >&2
fi

case "$mode" in
  claude) exec claude --dangerously-skip-permissions "$@" ;;
  opencode) exec opencode --auto "$@" ;;
  shell) exec bash "$@" ;;
  *)
    echo "sandbox-entrypoint: unknown mode '$mode' (claude, opencode, shell)" >&2
    exit 2
    ;;
esac
