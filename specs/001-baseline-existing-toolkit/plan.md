# Implementation Plan: Baseline the Existing Toolkit

**Branch**: `001-baseline-existing-toolkit` | **Date**: 2026-10-30 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/001-baseline-existing-toolkit/spec.md`

## Summary

Bring the existing dev environment (bash/OMB, tmux, Neovim with vendored plugins, the `dev`
picker, small helpers) up to constitution v1.0.0, and add a way to prove it on macOS and Linux.

The approach:

- **Entry scripts**: replace the Taskfile and the committed Linux-only `go-task` binary with
  three bash-3.2-compatible scripts at the repo root (`install.sh`, `pack.sh`, `unpack.sh`) that
  share one `lib.sh`.
- **Overrides**: move every override into user-owned locations (`~/.bashrc`,
  `~/.config/local/`), so install can safely replace the paths it owns.
- **Archive**: make it self-restoring and aware of the platform it was made on.
- **Session tools**: rewrite `dev` without `eval`, with deterministic session names.
- **Removals**: delete unused material (the AI runner, `claude-session`, `kubectx-create`, `ifi`,
  373 copied LSP configs, the stale lock file).
- **Verification**: add `tests/verify.sh` (lint plus a smoke test in a sandbox home, Linux in a
  container, macOS native) and a CI workflow running it on both OSes.

The detailed decisions are in [research.md](./research.md).

## Technical Context

**Language/Version**: Bash. The entry scripts and the test harness run on bash ≥ 3.2 (stock
macOS); the interactive shell config keeps its existing bash ≥ 4 guards. There is Lua for the
Neovim config and tmux config syntax.

**Primary Dependencies**: Runtime pre-requisites are bash, git, tmux, Neovim, fzf, tar and find.
Vendored dependencies are oh-my-bash and 13 Neovim plugins, all as pinned git submodules.

**Storage**: Files only (see [data-model.md](./data-model.md)).

**Testing**: `bash -n` + shellcheck + a grep gate for portability constructs; `tests/smoke.sh`
in a `mktemp -d` home; a Linux run in a Debian container, with unpack under `--network none`;
CI on `ubuntu-latest` and `macos-latest`.

**Target Platform**: macOS (Apple silicon and Intel) and glibc Linux (x86-64 and arm64).

**Project Type**: CLI toolkit / dotfiles distribution.

**Performance Goals**: Install takes under 2 minutes (SC-001). Full verification takes under
5 minutes (SC-003). The picker responds in under 3 seconds over 200 repos (SC-005).

**Constraints**:
- Install and unpack work offline once the repo or archive is present.
- Nothing is written outside the managed paths and the override stubs.
- No GNU-only or BSD-only flags.

**Scale/Scope**: A single user on a handful of machines. About 10 shell scripts and 8 components.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle / Rule | Status | How the design complies |
|------------------|--------|-------------------------|
| I. Portable macOS + Linux | ✅ | bash 3.2 baseline, a grep gate for one-platform flags, `uname` branches only in `lib.sh`/tmux, the platform guard on `esc-caps-swap`, verify on both OSes (R1, R6, R10) |
| II. One-command install/update | ✅ | `./install.sh` is idempotent, checks pre-requisites before any write, and only touches the managed list in `lib.sh` (R3, R4) |
| III. Transferable via files | ✅ | Vendored submodules (oh-my-bash converted); one archive with its own `unpack.sh`; runtime state carried; offline proven with `--network none` (R5, R8) |
| IV. Overwriteable | ✅ | Managed paths are replaced wholesale; overrides live outside them in `~/.config/local/` and `~/.bashrc`, are created once, load last and are never packed (R3) |
| V. Minimal and simple | ✅ | Net deletion of the Taskfile, the binary, AI tooling, the duplicate picker and ~375 files; no new language or test framework; `set -euo pipefail` in standalone scripts (R2, R9) |
| Tech constraint: root-level `install.sh` / `pack.sh` / `unpack.sh` are the only entry points, no task runner (v1.1.0) | ✅ | Exactly these three scripts plus `lib.sh`; `Taskfile.yaml` and `go-task` deleted (R2) |
| Tech constraint: entry scripts run on bash 3.2 (v1.1.0) | ✅ | The R1 dialect rules; lint runs `shellcheck -s bash`, and the macOS smoke test runs the entry scripts with `/bin/bash` (3.2) |
| Tech constraint: layout `env/` mirrors `$HOME`, vendor under `env/vendor/` | ✅ | Unchanged; the new overrides in `~/.config/local/` are user-owned, not repo layout |
| Tech constraint: `CONTEXT.md` vocabulary | ✅ | install / pack / unpack used throughout; `CONTEXT.md` updated to drop `install-locally` |
| Dev workflow: macOS + Linux check before merge | ✅ | `tests/verify.sh` plus the CI workflow |
| Dev workflow: README updated alongside changes | ✅ | The README rewrite is part of this feature |
| Dev workflow: pinned vendor commits | ✅ | All of `env/vendor/` are submodule gitlinks |

**Gate result** (constitution v1.1.0): PASS with no deviations. The earlier Taskfile deviation
was resolved by the v1.1.0 amendment.

**Post-design re-check (after Phase 1)**: PASS. The data model, contracts and quickstart make
Principle IV concrete (override table, load order) and Principle III concrete (archive layout,
MANIFEST). `contracts/cli.md` defines exactly the three entry scripts the amended constraint
names.

## Project Structure

### Documentation (this feature)

```text
specs/001-baseline-existing-toolkit/
├── spec.md
├── current-state.md     # pre-spec assessment of how the repo is built today
├── plan.md              # this file
├── research.md          # R1–R10 decisions
├── data-model.md        # components, overrides, archive, roots file
├── quickstart.md        # end-to-end validation guide
├── contracts/cli.md     # command contracts (entry scripts + installed commands)
├── checklists/requirements.md
└── tasks.md             # /speckit-tasks (not yet created)
```

### Source Code (repository root)

```text
install.sh               # NEW  install/update (replaces Taskfile install)
pack.sh                  # NEW  build dev-sessionizer.tar.gz
unpack.sh                # NEW  unpack from inside extracted archive
lib.sh                   # NEW  managed-path list, prereq check, platform helpers
Taskfile.yaml            # DELETE
tests/
├── verify.sh            # NEW  lint | linux | mac | all
├── smoke.sh             # NEW  scenarios run in a sandbox $HOME
└── Dockerfile           # NEW  debian slim + prerequisites
.github/workflows/
└── verify.yml           # NEW  CI on ubuntu-latest + macos-latest
env/
├── .bashrc.example      # EDIT load order + wording
├── .config/
│   ├── ai/              # DELETE
│   ├── bash/dev-sessionizer.bash   # EDIT PATH, brew shellenv, local/bin, drop ifi
│   ├── bin/
│   │   ├── dev          # REWRITE (R7)
│   │   ├── dev-gc       # keep
│   │   ├── esc-caps-swap# EDIT platform guard
│   │   └── claude-session, kubectx-create, unpack, update-dev, go-task  # DELETE
│   ├── k9s/             # keep
│   ├── nvim/
│   │   ├── init.lua     # EDIT source ~/.config/local/nvim.lua
│   │   ├── lua/config/keymaps.lua  # keep
│   │   ├── lsp/         # DELETE (373 files)
│   │   └── nvim-pack-lock.json     # DELETE
│   ├── oh-my-bash/custom/          # keep
│   └── tmux/tmux.conf   # EDIT default-command, wl-copy, source local override
└── vendor/
    ├── nvim/*           # keep (submodules)
    └── oh-my-bash       # CONVERT tracked files → pinned submodule
README.md, CONTEXT.md, .gitignore  # EDIT
```

**Structure Decision**: Single flat toolkit. The entry scripts sit at the repo root so the first
command is discoverable (`./install.sh`). `env/` keeps mirroring `$HOME`. Tests live in `tests/`.
No `src/` folder, because there is no application code.

## Implementation Order (for /speckit-tasks)

1. ~~Amend the constitution (v1.1.0)~~: done on 2026-10-30.
2. **US1 foundation**: `tests/verify.sh lint`, run against the current tree to get a baseline of
   failures.
3. **US2**: `lib.sh` and `install.sh`, the smoke test for install, idempotency and missing
   pre-requisites, then the Linux container target.
4. **US3**: override stubs and load-order edits, plus smoke assertions for them.
5. **Removals and clean-ups** (R9). These are mostly independent and can run in parallel with
   US3.
6. **US4**: `pack.sh` / `unpack.sh`, MANIFEST, the `--network none` smoke test.
7. **US5**: the `dev` rewrite.
8. **US6**: the `esc-caps-swap` guard.
9. **Vendoring**: convert oh-my-bash to a submodule (R8).
10. **Docs and CI**: README, `CONTEXT.md`, `.bashrc.example`, `verify.yml`.

## Complexity Tracking

There are no violations. The Taskfile entry-point deviation recorded in the first version of this
plan was resolved by constitution v1.1.0 (2026-10-30).
