# Current-State Assessment: Existing Toolkit

**Date**: 2026-10-30
**Purpose**: Record how the existing functionality is built and maintained today, measured against
constitution v1.0.0, as input to [spec.md](./spec.md).

## How the toolkit is developed today

| Aspect | Today | Gap vs constitution |
|--------|-------|---------------------|
| Specs / plans | None; 94 commits straight to `main` | All behaviour is implicit |
| Verification | None: no lint, tests, or CI; changes are checked by hand on whichever machine is in use | Dev Workflow requires a macOS + Linux check before merge |
| Docs | README, `CONTEXT.md`, `.bashrc.example` | They disagree: README says `task install`, the others say `task install-locally` |
| Pre-requisites | Listed in README (partially) | `task`, `openssl`, `jq`, `xsel`, `docker` and `gsettings` are used but not listed; nothing is checked at install time (Principle II) |

## Inventory and findings

### Install / update (`Taskfile.yaml: install`)

- Runs `rm -rf` on `~/.config/{tmux,nvim,bin,oh-my-bash,k9s,ai}` and then copies over them, so
  local edits in those folders are silently lost. Shell config is the only part with an override
  point (`~/.bashrc`) (Principle IV).
- There is no override point for nvim, tmux, k9s or personal scripts.
- Optional completions (`flux`, `talosctl`, `go-task`) are skipped correctly when the tool is
  missing ✅.

### Transport (`pack`, `unpack`, `bin/unpack`, `bin/update-dev`)

- `pack` builds dirs with `{share,state}/{nvim}`. A single-item brace is not expanded, so this
  creates literal `{nvim}` folders.
- `test -d X && cp …` makes the task fail when nvim state does not exist yet.
- Two overlapping restore scripts: `unpack` calls `go-task`, `update-dev` calls `task`, and
  `update-dev` relies on `realpath`.
- The task runner itself is shipped as a committed **Linux x86-64** binary
  (`bin/go-task`, ~210k lines). It does not run on macOS or arm64, which means an airgapped Mac
  cannot unpack (Principles I, III).

### Vendoring

- Neovim plugins are pinned git submodules ✅.
- `oh-my-bash` is listed in `.gitmodules` but tracked as plain files, which is inconsistent.
- `nvim/nvim-pack-lock.json` is left over from an earlier plugin manager and lists plugins that
  are not vendored (e.g. `diagram.nvim`).
- `nvim/lsp/` holds 373 copied server configs (1.5 MB), but only 5 are enabled. The vendored
  `nvim-lspconfig` already provides them (Principle V).

### Session tools (`bin/dev`, `bin/claude-session`)

- Both duplicate the same project picker (reads `~/.devconfig`, uses `eval` on each line, then
  `find` and `fzf`).
- `dev` builds session names with `openssl rand -base64`, which can produce `/` or `+` and breaks
  tmux targets (`claude-session` already works around this). It also has an unquoted `cd $selected`.
- Neither one checks that `~/.devconfig`, `fzf` or `tmux` exist.

### Other tools

- `dev-gc`: clones a git URL into `~/<host>/<path>`. Clean, uses `set -euo pipefail` ✅.
- `kubectx-create`: always sets `--insecure-skip-tls-verify`.
- `esc-caps-swap`: GNOME-only, with no platform guard.
- `ai`, `ai-build`, `ai-init`: a containerised Claude Code runner. Needs docker, and `ai-init`
  needs the network.
- Shared bash file: a personal SSH alias (`ifi`) with a username baked in; PATH lists linuxbrew
  but not `/opt/homebrew`.
- tmux: picks the clipboard per platform (`pbcopy` / `xsel`) ✅. Wayland is not covered.

## Improvement directions

1. Add a repeatable verification step (lint, plus a smoke install into a throwaway home) that
   runs on macOS and on Linux.
2. Make one command handle install and update, check pre-requisites, and never delete user-owned
   files.
3. Give every customisable component a local override point.
4. Make pack/unpack work on both OSes and on both CPU architectures, with no network.
5. Remove dead or duplicated material, and gate personal or platform-specific tools.
