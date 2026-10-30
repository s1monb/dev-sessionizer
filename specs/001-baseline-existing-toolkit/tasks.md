---

description: "Task list for 001-baseline-existing-toolkit"
---

# Tasks: Baseline the Existing Toolkit

**Input**: Design documents from `/specs/001-baseline-existing-toolkit/`

**Prerequisites**: plan.md, spec.md, research.md (R1–R10), data-model.md, contracts/cli.md,
quickstart.md

**Tests**: These are in scope. User Story 1 *is* the verification capability (FR-001–FR-003), so
each later story adds its own smoke scenarios to `tests/smoke.sh`.

**Organization**: Tasks are grouped by user story so each one can be implemented and verified on
its own.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: can run in parallel (different files, no dependency on an unfinished task)
- **[Story]**: the user story the task belongs to (US1–US6)

## Path Conventions

- The entry scripts sit at the repo root: `install.sh`, `pack.sh`, `unpack.sh`, `lib.sh`.
- Installable files are under `env/`, mirroring `$HOME`. Tests are under `tests/`.
- **Applies to every new script**: write for bash 3.2. That rules out associative arrays,
  `mapfile`/`readarray`, `${v,,}`, `&>>` and `declare -n`. Guard empty arrays under `set -u` as
  `${arr[@]+"${arr[@]}"}` (R1). Start each standalone script with
  `#!/usr/bin/env bash` and `set -euo pipefail`.

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Branch and the bare file layout

- [X] T001 Create and switch to git branch `001-baseline-existing-toolkit` from `main` (repo root)
- [X] T002 [P] Create `tests/` with empty executable files `tests/verify.sh` and `tests/smoke.sh`, and an empty `tests/Dockerfile`
- [X] T003 [P] Update `.gitignore`:
  - add `dev-sessionizer.tar.gz` and `/backup/`;
  - remove the `ghcr-io-s1monb-dev*` line;
  - keep `.local` and `.claude`.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Create `lib.sh`. It is the single source of shared logic for install, pack, unpack
and the tests.

**⚠️ CRITICAL**: No user story work can begin until this phase is complete.

- [X] T004 Create `lib.sh` (sourced, no shebang execution) with:
  - `DS_ROOT`: the folder containing `lib.sh`, resolved with `cd "$(dirname "${BASH_SOURCE[0]}")" && pwd`. Do **not** use `readlink -f` or `realpath`.
  - `ds_os`: prints `uname -s`.
  - `ds_arch`: prints `uname -m`.
  - `ds_log` and `ds_err`: `ds_log` writes to stdout and `ds_err` to stderr, each prefixed with `dev-sessionizer:`.
- [X] T005 In `lib.sh`, define the managed-path list as one plain indexed array, `DS_MANAGED=(...)`, copied from the data-model.md Component table:
  - `$HOME/.config/bash/dev-sessionizer.bash`
  - `$HOME/.config/bash/completions`
  - `$HOME/.config/oh-my-bash`
  - `$HOME/.config/tmux`
  - `$HOME/.config/nvim`
  - `$HOME/.config/bin`
  - `$HOME/.config/k9s`
  - `$HOME/.local/share/nvim/site/pack/vendor/start`

  This is the only place these paths are listed. Rule: "Install never deletes anything outside that list."
  *Implemented as the function `ds_managed` (prints one path per line) rather than an array: an array is expanded once at source time, so the tests read the real `$HOME` instead of the sandbox.*
- [X] T006 In `lib.sh`, add `ds_check_prereqs`:
  - Loop over the hard pre-requisites `bash git tmux nvim fzf tar find` with `command -v`, collecting every missing one.
  - For each of `nvim` and `tmux` that `command -v` found, check its minimum version: `nvim --version` (first line) ≥ 0.12 and `tmux -V` ≥ 3.2. Parse them with bash string handling and compare major/minor as integers. Collect each one that is too old as `outdated: nvim 0.10.4 (need ≥ 0.12)`.
  - If anything is missing or outdated, print `missing: a, b, …` and/or the `outdated:` lines to stderr (everything at once), and return 1.
  - Then check that `env/vendor/oh-my-bash` and every folder in `env/vendor/nvim/` exist and are non-empty. If not: when `$DS_ROOT/.git` exists, print `run: git submodule update --init --recursive`; otherwise print `incomplete archive: env/vendor/<name> missing`. Return 1.
  - It MUST NOT write any file (contracts/cli.md install table).
- [X] T007 In `lib.sh`, add `ds_guard_sandbox_home`. It returns 1 with an error unless `DS_SANDBOX=1` is set **and** `$HOME` is different from `DS_REAL_HOME` (FR-003). The tests call it before every install/unpack.

**Checkpoint**: `bash -n lib.sh` passes; sourcing it under `/bin/bash` (3.2) on macOS raises no errors.

---

## Phase 3: User Story 1 - Verify a change on both platforms (Priority: P1) 🎯 MVP

**Goal**: One command, `tests/verify.sh [lint|mac|linux|all]`, reports PASS/FAIL per target and never touches the real `$HOME`.

**Independent Test**: Run `tests/verify.sh lint` on the current tree. It must finish with PASS or FAIL naming file:line. A planted `sed -i 's/a/b/' x` in any shipped script must make it FAIL (quickstart §1).

> Expected at this point: `lint` FAILS on the existing tree (for example `dev` has unquoted `cd $selected`). That is the baseline. Later phases fix those findings.

- [X] T008 [US1] Implement the `lint` target in `tests/verify.sh`.
  - Collect the shipped scripts:
    - `install.sh`, `pack.sh`, `unpack.sh`, `lib.sh`;
    - `tests/*.sh`;
    - every file in `env/.config/bin/` whose first line matches `^#!.*(ba)?sh`;
    - `env/.config/bash/dev-sessionizer.bash`, `env/.bashrc.example`;
    - `env/.config/oh-my-bash/custom/**/*.sh`.
  - Run `bash -n` on each file.
  - Then run `shellcheck -s bash` on each: use local `shellcheck` if `command -v shellcheck`, otherwise `docker run --rm -v "$PWD:/mnt" -w /mnt koalaman/shellcheck-alpine:stable shellcheck -s bash …`.
  - Print `PASS lint` or `FAIL lint: <file>:<line> <message>`.
- [X] T009 [US1] Add a portability grep gate to the `lint` target in `tests/verify.sh`.
  - Fail on any line in the shipped scripts matching `sed -i`, `readlink -f`, `date -d`, `realpath`, `grep -P`, `mapfile`, `readarray`, `declare -A`, `declare -n`, `${…,,}` / `${…^^}` (case-modification expansions), `&>>`, or the `;&` / `;;&` case terminators, unless the same line contains `# portable-ok`.
  - Network gate: in `install.sh`, `pack.sh`, `unpack.sh` and `lib.sh` (whichever exist), fail on any line matching `curl|wget|git (clone|fetch|pull|submodule update)`. Ignore lines whose first command is `echo`, `printf`, `ds_log` or `ds_err`, and lines marked `# portable-ok` (FR-010).
  - Report each failure as `file:line`.
- [X] T010 [US1] Create the harness skeleton in `tests/smoke.sh`.
  - Set `DS_REAL_HOME="$HOME"`, `DS_RUN="$(mktemp -d)"`, `export DS_SANDBOX=1`, and `trap 'rm -rf "$DS_RUN"' EXIT`.
  - Source `lib.sh`.
  - Add the helper `new_sandbox`: `export HOME="$(mktemp -d "$DS_RUN/home.XXXXXX")"`, then `ds_guard_sandbox_home`. Every `scenario_*` calls `new_sandbox` first, so scenarios never share state. A scenario that needs a second home (for example the unpack target) calls it again.
  - Set `DS_BASH="${DS_BASH:-bash}"`. Every scenario runs the entry scripts as `"$DS_BASH" ./install.sh`, `"$DS_BASH" ./pack.sh` and `"$DS_BASH" ./unpack.sh`, never directly, so the interpreter under test is explicit. On macOS, assert that `"$DS_BASH" --version` reports `3.2` when `DS_BASH=/bin/bash`.
  - Add helpers:
    - `assert_ok "<desc>" cmd…`
    - `assert_fail "<desc>" cmd…`
    - `assert_eq "<desc>" a b`
    - `checksum_tree <dir>`, using `find … -type f | LC_ALL=C sort | xargs cksum` (portable).
  - Each scenario is a function named `scenario_*`. The script runs them all, prints `ok`/`not ok <desc>`, and exits non-zero on any failure.
- [X] T011 [P] [US1] Write `tests/Dockerfile`.
  - Base `FROM debian:stable-slim`.
  - `apt-get install -y --no-install-recommends bash git tmux fzf tar findutils ca-certificates curl xsel`. Do not install apt's `neovim`: Debian stable ships 0.10, and the config needs ≥ 0.12 (the vendored blink.cmp v2 refuses to load on older versions).
  - Install the official Neovim v0.12.x release tarball for the container's architecture: `nvim-linux-$(uname -m | sed 's/aarch64/arm64/').tar.gz` from `https://github.com/neovim/neovim/releases/download/v0.12.<x>/`, unpacked to `/opt/nvim` and symlinked to `/usr/local/bin/nvim`. Pin the exact patch version.
  - Create a non-root user `tester`, set `WORKDIR /src`, and use `CMD ["bash","tests/smoke.sh"]`.
- [X] T012 [US1] Implement the `linux` target in `tests/verify.sh`.
  - Run `docker build -t ds-verify -f tests/Dockerfile .`.
  - Then `docker run --rm -v "$PWD:/src:ro" ds-verify bash tests/smoke.sh`.
  - Print `PASS linux` or `FAIL linux: <first failing scenario>`.
  - If docker is absent, print `FAIL linux: docker not found`.
- [X] T013 [US1] Implement the `mac` target in `tests/verify.sh`.
  - Only on `uname -s` = `Darwin`; elsewhere print `SKIP mac`.
  - Run `DS_BASH=/bin/bash /bin/bash tests/smoke.sh`, so both the harness and every entry script run under bash 3.2 (R6, constitution v1.1.0).
  - Print `PASS mac` or `FAIL mac: …`.
- [X] T014 [US1] Implement the `all` target (the default) in `tests/verify.sh`: run `lint`, `linux`, `mac` in that order, print every result line, and exit 1 if any FAIL. Add `-h`/usage text that lists the targets (contracts/cli.md).

**Checkpoint**: `tests/verify.sh lint` runs and reports. `smoke.sh` runs with zero scenarios and refuses to run when `DS_SANDBOX` is unset.

---

## Phase 4: User Story 2 - Install or update with one command (Priority: P1)

**Goal**: `./install.sh` installs or updates every component, is idempotent, checks pre-requisites before writing, and works offline (FR-005–FR-010).

**Independent Test**: In the sandbox, run `./install.sh` twice. Managed paths are identical across the runs; a new interactive bash has the shared prompt; `nvim --headless +qa` writes nothing to stderr; the tmux config loads (quickstart §2).

### Tests for User Story 2

- [X] T015 [P] [US2] In `tests/smoke.sh`, add `scenario_install_twice_idempotent`:
  - After `new_sandbox`, run `"$DS_BASH" ./install.sh` three times, recording `checksum_tree` for each entry of `DS_MANAGED` after each run.
  - `assert_eq` all three sets of checksums (SC-002).
- [X] T016 [P] [US2] In `tests/smoke.sh`, add `scenario_missing_prereq_writes_nothing`.
  - Build a temp `bin/` holding symlinks to every hard pre-requisite except `tmux`, plus the basic utilities the scripts use: `env dirname basename uname cp rm mkdir cat sort cksum grep`. Without these, install would fail with "command not found" instead of `missing: tmux`.
  - After `new_sandbox`, run `PATH="$tmpbin" "$DS_BASH" ./install.sh`.
  - `assert_fail`; check that stderr contains `missing:` and `tmux` and does **not** contain `command not found` (if it does, the basic-utilities list is out of date); check that `find "$HOME" -mindepth 1` is empty.
- [X] T017 [P] [US2] In `tests/smoke.sh`, add `scenario_components_load` (run after install):
  - `HOME="$HOME" bash -ic 'printf %s "$PS1"'` is non-empty;
  - `nvim --headless +qa 2>&1` is empty;
  - `tmux -L ds-verify -f "$HOME/.config/tmux/tmux.conf" new-session -d true && tmux -L ds-verify kill-server` succeeds;
  - `~/.config/bin/dev` is executable.
- [X] T018 [P] [US2] In `tests/smoke.sh`, add `scenario_install_time`: after `new_sandbox`, run `"$DS_BASH" ./install.sh` and use bash `SECONDS` to assert it completes in under 120 s (SC-001).

### Implementation for User Story 2

- [X] T019 [US2] Create `install.sh`.
  - Use `#!/usr/bin/env bash` and `set -euo pipefail`, then `source "$(dirname "$0")/lib.sh"`.
  - Call `ds_check_prereqs` first and exit 1 on failure, before any write.
  - Then, for each entry in `DS_MANAGED`, `rm -rf` it and copy from its repo source using the mapping in data-model.md:
    - oh-my-bash: copy `env/vendor/oh-my-bash` and then overlay `env/.config/oh-my-bash/custom/.`, excluding any `.git` file.
    - nvim plugins: copy each `env/vendor/nvim/*` folder into `~/.local/share/nvim/site/pack/vendor/start/`, excluding `.git`.
  - Use only `cp -R`, `mkdir -p` and `rm -rf`: no `rsync`, no GNU-only `cp` flags.
  - Then create `~/.bashrc` from `env/.bashrc.example` **only if it does not exist yet** (`[[ -e "$HOME/.bashrc" ]] || cp …`). It is never overwritten afterwards (FR-012). It lives here, not in US3, because the US2 prompt check (T017) needs it.
- [X] T020 [US2] Add optional completions to `install.sh`.
  - Run `mkdir -p ~/.config/bash/completions`.
  - For each of `flux` and `talosctl`: if `command -v` finds it, write `<tool> completion bash > ~/.config/bash/completions/<tool>.bash`; otherwise skip silently (FR-009).
  - Do NOT generate `go-task` completions (R2).
- [X] T021 [US2] Make `install.sh` print a one-line summary on success, `installed N components from <DS_ROOT>`, and exit 0. (The network check runs in the T009 lint gate, FR-010.)
- [X] T022 [P] [US2] Edit `env/.config/tmux/tmux.conf`:
  - change `set-option -g default-command /bin/bash` to `set-option -g default-command "exec bash"`;
  - in the Linux `if-shell` block, use `wl-copy` when `$WAYLAND_DISPLAY` is set and `xsel -i -b` otherwise (R10).
- [X] T023 [P] [US2] Edit `env/.config/bash/dev-sessionizer.bash`:
  - remove the hard-coded `/home/linuxbrew/.linuxbrew/bin` from PATH;
  - add: `for __b in /opt/homebrew/bin/brew /usr/local/bin/brew /home/linuxbrew/.linuxbrew/bin/brew; do [[ -x $__b ]] && { eval "$("$__b" shellenv)"; break; }; done; unset __b` before the PATH export;
  - remove `$HOME/.config/ai/bin` from PATH (R9, R10).
- [X] T024 [US2] Delete the copied LSP configs `env/.config/nvim/lsp/` (373 files; the 5 enabled ones are unmodified older copies of the vendored nvim-lspconfig, R9) and `env/.config/nvim/nvim-pack-lock.json`. Then confirm `nvim --headless "+lua for _,s in ipairs({'lua_ls','rust_analyzer','tinymist','marksman','ts_ls'}) do assert(vim.lsp.config[s], s) end" +qa` succeeds after install (FR-025).
- [X] T025 [US2] Run `tests/verify.sh mac` and `tests/verify.sh linux`; fix until the US2 scenarios pass.

**Checkpoint**: A clean sandbox gets a working shell, tmux and Neovim from `./install.sh` on both platforms.

---

## Phase 5: User Story 3 - Machine-local customisations survive (Priority: P2)

**Goal**: Override locations `~/.bashrc` and `~/.config/local/{nvim.lua,tmux.conf,bin/}` are created once, never rewritten, and loaded after the shared defaults (FR-011–FR-014, R3).

**Independent Test**: Add markers to each override, run install again: the markers are still in the files and active (quickstart §3).

### Tests for User Story 3

- [X] T026 [P] [US3] In `tests/smoke.sh`, add `scenario_overrides_survive_and_load`:
  - After the first install, append these markers:
    - `vim.g.local_marker = 1` to `~/.config/local/nvim.lua`;
    - `set -g @local_marker 1` to `~/.config/local/tmux.conf`;
    - an executable `~/.config/local/bin/dev` that prints `local-dev`;
    - `export DS_LOCAL_MARKER=1` to `~/.bashrc`.
  - Run `./install.sh` again. `assert_eq` each file's cksum is unchanged.
  - Then check:
    - `nvim --headless '+lua io.write(vim.g.local_marker)' +qa` prints `1`;
    - `tmux -L ds-verify -f ~/.config/tmux/tmux.conf new-session -d \; show -gv @local_marker` prints `1`;
    - `bash -ic 'dev; echo $DS_LOCAL_MARKER'` prints `local-dev` and `1`.

### Implementation for User Story 3

- [X] T027 [US3] In `install.sh`, after the managed copy, create the override stubs **only when absent** (`[[ -e X ]] || …`):
  - `~/.config/local/` and `~/.config/local/bin/`;
  - `~/.config/local/nvim.lua` and `~/.config/local/tmux.conf`, each containing a one-line comment `-- machine-local overrides (never touched by install)` or the `#` equivalent.

  (`~/.bashrc` is already created once by T019.)

  `~/.config/local` MUST NOT appear in `DS_MANAGED`.
- [X] T028 [P] [US3] Append to the end of `env/.config/nvim/init.lua`: `local local_cfg = vim.fn.expand('~/.config/local/nvim.lua'); if vim.uv.fs_stat(local_cfg) then dofile(local_cfg) end`
- [X] T029 [P] [US3] Append as the last line of `env/.config/tmux/tmux.conf`: `source-file -q ~/.config/local/tmux.conf`
- [X] T030 [P] [US3] In `env/.config/bash/dev-sessionizer.bash`, put `$HOME/.config/local/bin` **before** `$HOME/.config/bin` on PATH (*implemented at the very front of PATH, so local scripts also override system binaries*) so local scripts win. Remove the `alias ifi=…` line, since personal settings belong in overrides (FR-014, FR-024).
- [X] T031 [P] [US3] Rewrite `env/.bashrc.example` so it sources `~/.config/bash/dev-sessionizer.bash` **first**, followed by a commented section `# machine-local settings below (override shared defaults)`. Replace every mention of `install-locally` with `./install.sh`.
- [X] T032 [US3] Run `tests/verify.sh mac` and `tests/verify.sh linux`; fix until the US3 scenario passes.

**Checkpoint**: Overrides are created once, kept across installs and take precedence.

---

## Phase 6: User Story 4 - Move the environment to an airgapped machine (Priority: P2)

**Goal**: `./pack.sh` produces one self-restoring archive. `tar -xzf … && ./dev-sessionizer/unpack.sh` works offline and is aware of the platform (FR-015–FR-018, R5).

**Independent Test**: Pack in the sandbox and unpack into a fresh sandbox home with `--network none` on Linux. The environment is installed, runtime state is restored, overrides are untouched (quickstart §4).

### Tests for User Story 4

- [X] T033 [P] [US4] In `tests/smoke.sh`, add `scenario_pack_without_runtime_state`: after `new_sandbox` (so there is no `~/.local/share/nvim` or `~/.local/state/nvim`), `"$DS_BASH" ./pack.sh "$DS_RUN/a.tar.gz"` succeeds; the archive exists; `tar -tzf` lists `dev-sessionizer/MANIFEST` and no `dev-sessionizer/runtime/`; no stray temp folders remain under `$TMPDIR` or the cwd.
- [X] T034 [P] [US4] In `tests/smoke.sh`, add `scenario_pack_unpack_roundtrip`.
  - After `new_sandbox` and install, create `~/.local/share/nvim/marker` and `~/.local/state/nvim/marker`.
  - Run pack.
  - Call `new_sandbox` again for the target home, then pre-create `~/.config/local/nvim.lua` holding the text `keep`, and a stale runtime file `~/.local/share/nvim/stale`.
  - Run `tar -xzf`, then `"$DS_BASH" ./dev-sessionizer/unpack.sh`.
  - Assert:
    - both markers are restored;
    - `~/.local/share/nvim/stale` is gone (unpacking onto an older install gives the same result as a clean machine);
    - `~/.config/local/nvim.lua` still contains `keep`;
    - `~/.local/share/nvim/site/pack/vendor/start` came from install, not from the archive.
- [X] T035 [P] [US4] In `tests/smoke.sh`, add `scenario_unpack_platform_mismatch`: edit the extracted `MANIFEST` to `arch=bogus`, then run `unpack.sh`. It exits 0, prints `runtime state from <os>/bogus skipped on <os>/<arch>`, and does not restore the markers.
- [X] T036 [US4] In `tests/verify.sh` `linux` target, run the roundtrip unpack step in a second container with `docker run --network none`. Pack in container 1 writing to a shared volume, unpack in container 2 (SC-004).

### Implementation for User Story 4

- [X] T037 [US4] Create `pack.sh [OUTPUT]` (default `./dev-sessionizer.tar.gz`):
  - Stage in `stage="$(mktemp -d)"` with `trap 'rm -rf "$stage"' EXIT`.
  - Copy into `$stage/dev-sessionizer/`: `install.sh`, `unpack.sh`, `lib.sh`, `README.md`, and `env/`. Then `find "$stage/dev-sessionizer/env" -name .git -exec rm -rf {} +`.
  - Copy runtime state only if it exists:
    - `~/.local/share/nvim` → `runtime/share/nvim`, then `rm -rf` its `site/pack/vendor`;
    - `~/.local/state/nvim` → `runtime/state/nvim`.
  - Write `MANIFEST` with `os=$(ds_os)`, `arch=$(ds_arch)` and `created=$(date -u +%Y-%m-%dT%H:%M:%SZ)`.
  - Run `tar -czf "$OUTPUT" -C "$stage" dev-sessionizer`.
  - Exit 1 if `OUTPUT`'s folder is not writable.
- [X] T038 [US4] Create `unpack.sh`. It runs from inside the extracted `dev-sessionizer/` and sources its sibling `lib.sh`.
  - Run `"$BASH" "$DS_ROOT/install.sh"`, so install runs under the same interpreter as unpack. If install fails, exit with its code and do not touch runtime state.
  - Read `os=`/`arch=` from `MANIFEST` with `while IFS='=' read -r k v`, not `eval` or `source`.
  - If both match `ds_os`/`ds_arch`: first remove every entry under `~/.local/share/nvim` except `site`, and remove `~/.local/state/nvim` (this replaces the old Taskfile `clean`). Then copy `runtime/share/nvim/.` into `~/.local/share/nvim/` and `runtime/state/nvim/.` into `~/.local/state/nvim/` (only those present).
  - Otherwise print the mismatch warning from contracts/cli.md and skip.
  - It never writes under `~/.config/local` or `~/.bashrc`.
- [X] T039 [US4] Delete `Taskfile.yaml`, `env/.config/bin/go-task`, `env/.config/bin/unpack` and `env/.config/bin/update-dev`. Replace every reference to `task install`, `task pack`, `task unpack`, `go-task` or `update-dev` in the repo with the root scripts: `grep -rn` across the repo, excluding `env/vendor` and `specs/` (FR-017, FR-018, R2).
- [X] T040 [US4] Run `tests/verify.sh linux` and `tests/verify.sh mac`; fix until the US4 scenarios pass.

**Checkpoint**: The archive restores offline. The task runner is gone.

---

## Phase 7: User Story 5 - Jump into a project session (Priority: P3)

**Goal**: `dev` is the only session tool. It has safe roots-file parsing, deterministic tmux-valid session names, open-or-switch behaviour, and clear errors (FR-019–FR-022, R7).

**Independent Test**: With a roots file listing two folders that contain git repos (plus one root that doesn't exist), `dev <path>` creates a session and a second `dev <path>` switches to it without a duplicate (quickstart §5).

### Tests for User Story 5

- [X] T041 [P] [US5] In `tests/smoke.sh`, add `scenario_dev_sessions`. It runs on a private tmux socket via `TMUX_TMPDIR="$HOME/tmux"`, and creates `$HOME/p/a.b c/.git` and `$HOME/q/a.b c/.git`. Assert:
  - `dev "$HOME/p/a.b c"` run outside tmux with `TMUX=` (using `DS_DEV_NO_ATTACH=1` so the test does not block on attach) creates the session `a_b_c`;
  - a repeat call leaves `tmux ls | wc -l` at 1;
  - `dev "$HOME/q/a.b c"` creates `a_b_c_q`.
- [X] T042 [P] [US5] In `tests/smoke.sh`, add `scenario_dev_roots_file`:
  - roots file lines `# c`, a blank line, `~/p`, `$HOME/q` and `${HOME}/missing`, plus a line `$(touch $HOME/pwned)`;
  - the internal list function `dev --list` prints exactly the 2 repos;
  - `$HOME/pwned` does not exist;
  - with no `~/.devconfig`, `dev --list` exits 1 and its stderr mentions `~/.devconfig`.
- [X] T043 [P] [US5] In `tests/smoke.sh`, add `scenario_dev_list_200`: generate 200 `…/.git` folders split across 2 roots, then assert that `dev --list` prints 200 lines in under 3 s, measured with bash `SECONDS` (SC-005).

### Implementation for User Story 5

- [X] T044 [US5] Rewrite `env/.config/bin/dev` (bash 3.2, `set -euo pipefail`):
  - `ds_expand` handles a leading `~` and repeatedly replaces `\$\{?([A-Za-z_][A-Za-z0-9_]*)\}?` using `BASH_REMATCH` and indirect expansion `${!name-}`. It does **not** use `eval`.
  - `--list` reads `~/.devconfig`, skipping `#` lines, blank lines and roots that don't exist, and runs `find "$root" -mindepth 1 -type d -exec test -e '{}/.git' ';' -print -prune 2>/dev/null`.
  - Without arguments it pipes `--list` to `fzf`. Cancelling exits 0.
  - Missing `~/.devconfig`, `fzf` or `tmux` → stderr message naming the item and its fix, exit 1.
- [X] T045 [US5] Add session naming to `env/.config/bin/dev`:
  - `name="$(printf '%s' "$(basename "$dir")" | tr -c 'A-Za-z0-9_-' '_')"`. Keep `-` last in the set; `_-\n` would be read as a reversed range.
  - If `tmux has-session -t "=$name"` succeeds and `tmux display -p -t "=$name" '#{session_path}'` equals `$dir`, reuse the session.
  - If it exists for another path, use `${name}_<parent>`, where `<parent>` is the parent folder's basename passed through the same `printf … | tr -c 'A-Za-z0-9_-' '_'`.
  - Create with `tmux new-session -ds "$name" -c "$dir"`.
  - Then `switch-client` if `$TMUX` is set, otherwise `attach` (skipped when `DS_DEV_NO_ATTACH=1`).
  - Do not use `openssl`.
- [X] T046 [US5] Delete `env/.config/bin/claude-session` (FR-021). Confirm the Ctrl-F binding in `env/.config/bash/dev-sessionizer.bash` still calls `dev`.
- [X] T047 [US5] Run `tests/verify.sh lint`, `tests/verify.sh mac` and `tests/verify.sh linux`; fix until the US5 scenarios pass.

**Checkpoint**: The picker is safe, deterministic and reports problems clearly.

---

## Phase 8: User Story 6 - Bundled helper commands (Priority: P3)

**Goal**: The remaining helpers are `dev-gc` and `esc-caps-swap`. Each works or exits clearly on unsupported platforms. The unused helpers are gone (FR-023, FR-024, FR-027).

**Independent Test**: On macOS, `esc-caps-swap` prints `esc-caps-swap: requires GNOME (gsettings)` and exits 1. `ls ~/.config/bin` shows only `dev`, `dev-gc` and `esc-caps-swap` (quickstart §6).

### Tests for User Story 6

- [X] T048 [P] [US6] In `tests/smoke.sh`, add `scenario_helpers`:
  - `env -u XDG_CURRENT_DESKTOP ~/.config/bin/esc-caps-swap` exits 1 with `requires GNOME`;
  - `~/.config/bin/dev-gc` with no args exits 1 with `Usage`;
  - `ls ~/.config/bin` equals `dev dev-gc esc-caps-swap`;
  - `~/.config/ai` does not exist;
  - `grep -r 'kubectx-create\|claude-session\|config/ai\|alias ifi' ~/.config` finds nothing.

### Implementation for User Story 6

- [X] T049 [P] [US6] Add a guard at the top of `env/.config/bin/esc-caps-swap`: unless `command -v gsettings` succeeds **and** `${XDG_CURRENT_DESKTOP:-}` contains `GNOME`, print `esc-caps-swap: requires GNOME (gsettings)` to stderr and exit 1. Add `set -euo pipefail`.
- [X] T050 [P] [US6] Delete `env/.config/bin/kubectx-create` and the whole `env/.config/ai/` folder (`Dockerfile`, `README.md`, `bin/ai`, `bin/ai-build`, `bin/ai-init`). Make sure no install step references them (FR-024).
- [X] T051 [US6] Check `env/.config/nvim/lua/config/keymaps.lua` `<leader>tg` (`:te esc-caps-swap`). Keep it; the guard makes it harmless on macOS. Make sure `dev-gc` still passes lint, with no behaviour change.
- [X] T052 [US6] Run `tests/verify.sh`; fix until the US6 scenario passes.

**Checkpoint**: Every shipped helper either works or explains why not.

---

## Phase 9: Polish & Cross-Cutting Concerns

**Purpose**: Vendoring consistency, docs, CI, final validation

- [X] T053 Convert `env/vendor/oh-my-bash` to a pinned submodule (R8, FR-026). This step needs the network.
  1. Note the upstream commit that best matches the tracked files: clone `https://github.com/ohmybash/oh-my-bash` to a scratch folder and compare with `git diff --no-index --stat` against candidate commits around the tree's file dates, or pick the latest commit before 2026-06-06.
  2. `git rm -r --cached env/vendor/oh-my-bash && rm -rf env/vendor/oh-my-bash`.
  3. `git submodule add https://github.com/ohmybash/oh-my-bash.git env/vendor/oh-my-bash`, then `git -C env/vendor/oh-my-bash checkout <commit>`.
  4. Commit with the message `vendor: track oh-my-bash as submodule at <commit>`.
  *Result: pinned at upstream `05e6d03` (2026-03-02). The tracked copy was that commit minus 20 docs/CI/example files, with no content changes. Staged; the commit is left to the maintainer.*
  5. Re-run the smoke test.
- [X] T054 [P] Rewrite `README.md`. Pre-requisites:
  - **hard**: bash, git, tmux ≥ 3.2, nvim ≥ 0.12, fzf, tar, find;
  - **optional**: xsel or wl-copy, direnv, jq, flux, talosctl, gsettings (GNOME), the bash-completion package; Docker for verification only.

  Install: `git clone --recursive …` then `./install.sh` (also for updates). Then:
  - an overrides table, taken from data-model.md;
  - airgapped transfer: `./pack.sh`, copy the archive, `tar -xzf dev-sessionizer.tar.gz && ./dev-sessionizer/unpack.sh`;
  - `tests/verify.sh`;
  - the Neovim plugin add/update workflow, unchanged;
  - remove the `task` commands and the stale TODO about sourcing `.bashrc` if it is resolved (FR-004, FR-008).
- [X] T055 [P] Update `CONTEXT.md`. Install is "triggered by `./install.sh`"; Unpack is "runs `unpack.sh` inside the extracted archive, which runs install and restores runtime state when the platform matches". Add the term **Override**: "a user-owned file under `~/.config/local/` or `~/.bashrc`, created once and never written by install", with *Avoid*: "customisation file, local config". Remove every mention of `install-locally` (FR-004).
- [X] T056 [P] Create `.github/workflows/verify.yml`, triggered `on: [push, pull_request]`.
  - Job `linux`: `ubuntu-latest`, `actions/checkout@v4` with `submodules: recursive`, then `tests/verify.sh lint` and `tests/verify.sh linux`.
  - Job `mac`: `macos-latest`, the same checkout, `brew install tmux neovim fzf`, then `tests/verify.sh mac`.
- [X] T057 Run `tests/verify.sh` (all). It MUST print `PASS lint`, `PASS linux` and `PASS mac` in under 5 minutes (SC-003). Check the real `ls -la ~/.config` is unchanged before and after.
- [ ] T058 Run the remaining manual scenarios in quickstart.md by hand: §1 (the planted-defect check, then revert) and §5 (the interactive `dev` picker with fzf). Record the results in the PR description.
- [X] T059 Check SC-006: `git ls-files env/.config/nvim | wc -l` is under 10, and there are zero tracked files that nothing uses. Keep `specs/001-baseline-existing-toolkit/current-state.md` as the record of the assessment.
- [X] T060 [P] Add the test hooks introduced by T041/T042 to `specs/001-baseline-existing-toolkit/contracts/cli.md` under `dev`: `dev --list` (prints the repos it finds, one per line) and the `DS_DEV_NO_ATTACH=1` env var (creates or reuses the session without attaching).

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: none.
- **Foundational (Phase 2)**: depends on Setup. It BLOCKS every story, because everything sources `lib.sh`.
- **US1 (Phase 3)**: depends on Phase 2. Its harness (T010–T014) is needed by every later story's tests.
- **US2 (Phase 4)**: depends on US1's harness. Every other story's scenarios run `./install.sh`.
- **US3, US4, US5, US6 (Phases 5–8)**: each depends only on US2 and can run in parallel. Watch for same-file collisions:
  - US3's T027 and US4's T038 both deal with `install.sh` / `unpack.sh` and override safety. Do US3 before US4 if done sequentially.
  - `tests/smoke.sh` is shared. Add scenarios as separate functions to keep merges trivial.
  - `env/.config/bash/dev-sessionizer.bash` is edited by T023 (US2) and T030 (US3). T030 goes after T023.
  - `env/.config/tmux/tmux.conf` is edited by T022 (US2) and T029 (US3). T029 goes after T022.
- **Polish (Phase 9)**: depends on all stories. T053 needs the network.

### User Story Dependencies

- **US1**: none beyond Foundational.
- **US2**: US1 (the harness).
- **US3**: US2.
- **US4**: US2; ideally after US3, for the override-preservation assertion in T034.
- **US5**: US2.
- **US6**: US2.

### Within Each User Story

- Write scenarios first. They fail until the implementation lands.
- Implementation, then the story's verify run (T025, T032, T040, T047, T052).

### Parallel Opportunities

- T002 and T003 (Setup).
- T011 alongside T008–T010 (Dockerfile versus harness).
- Within US2: T015, T016, T017, T018 (scenarios), then T022 and T023 (configs) alongside T019–T021 (`install.sh`).
- Within US3: T028, T029, T030, T031, which are four different files.
- US5 and US6 can be built in parallel with each other once US2 is done.
- Polish: T054, T055, T056.

---

## Parallel Example: User Story 3

```bash
Task: "Append local override sourcing to env/.config/nvim/init.lua (T028)"
Task: "Append source-file -q ~/.config/local/tmux.conf to env/.config/tmux/tmux.conf (T029)"
Task: "Prepend ~/.config/local/bin on PATH and drop ifi alias in env/.config/bash/dev-sessionizer.bash (T030)"
Task: "Rewrite env/.bashrc.example load order and wording (T031)"
```

## Parallel Example: User Story 2

```bash
Task: "scenario_install_twice_idempotent in tests/smoke.sh (T015)"
Task: "scenario_missing_prereq_writes_nothing in tests/smoke.sh (T016)"
Task: "Edit env/.config/tmux/tmux.conf default-command + wl-copy (T022)"
Task: "Edit env/.config/bash/dev-sessionizer.bash brew shellenv PATH (T023)"
```

---

## Implementation Strategy

### MVP First (User Story 1, then User Story 2)

1. Phases 1 and 2 (Setup, `lib.sh`).
2. Phase 3 (US1): `tests/verify.sh lint` gives immediate value on the current tree.
3. **STOP and VALIDATE**: the planted-defect check fails as expected.
4. Phase 4 (US2): a working `./install.sh` with smoke coverage on both OSes. At this point the toolkit is already better than today, and the Taskfile still exists for pack until US4 lands.

### Incremental Delivery

1. US1 + US2 → the MVP (verified install).
2. + US3 → updates are safe for local edits.
3. + US4 → airgapped transfer works on Mac and Linux, and the Taskfile and binary are deleted.
4. + US5 / US6 → picker fixes and the helper clean-up.
5. Polish → submodule, docs, CI, final verify.

Commit after each task or logical group, using conventional prefixes (`feat:`, `fix:`, `chore:`, `docs:`, `vendor:`).

---

## Notes

- [P] = different files, no dependency on an unfinished task.
- [Story] labels map tasks to the spec's user stories, for traceability.
- `tests/smoke.sh` is shared across stories. Keep each scenario in its own function.
- Never run `install.sh` or `unpack.sh` against the real `$HOME` while developing. Always go through `tests/smoke.sh` or an explicit `HOME=$(mktemp -d)`.
