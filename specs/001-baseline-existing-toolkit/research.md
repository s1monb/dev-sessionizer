# Research: Baseline the Existing Toolkit

**Date**: 2026-10-30 | **Spec**: [spec.md](./spec.md) | **Input**: [current-state.md](./current-state.md)

Each section records one decision, using the format Decision / Rationale / Alternatives.

## R1. Shell dialect for entry scripts

- **Decision**: `install.sh`, `pack.sh`, `unpack.sh` and `tests/verify.sh` target **bash 3.2**,
  which is stock `/bin/bash` on macOS. That means no associative arrays, `mapfile`, `${v,,}` or
  `&>>`. With `set -u`, empty arrays are guarded as `${arr[@]+"${arr[@]}"}`.
- **Rationale**: An airgapped Mac may not have Homebrew bash. The entry scripts must run before
  anything else is installed (Principles I and III).
- **Alternatives**: Require bash ≥ 4 everywhere. Rejected because it adds a pre-requisite to the
  very first command. POSIX `sh` was also rejected: it loses `[[ ]]` and `BASH_REMATCH` with no
  portability gain, because bash is already a hard pre-requisite.

## R2. Task runner replacement (FR-018)

- **Decision**: Delete `Taskfile.yaml` and the committed `env/.config/bin/go-task` binary. The
  entry points are the scripts at the repo root, and they share helpers from `lib.sh`. Drop the
  `go-task` completion generation from install.
- **Rationale**: This is the clarified choice (Q1: B). A thin Taskfile wrapper would keep a second
  way to do everything, for no benefit (Principle V).
- **Alternatives**: Keep `Taskfile.yaml` as a wrapper. Rejected because it is duplicate surface,
  and `task` would still be a pre-requisite in practice on machines that use it.
- **Constitution impact**: Resolved. Constitution v1.1.0 (2026-10-30) makes the root scripts the
  only entry points.

## R3. Install ownership model and override points (FR-006, FR-011–FR-013)

- **Decision**:
  - *Managed paths* are replaced wholesale on each install. That keeps install idempotent and
    removes stale files.
  - *Overrides* live **outside** managed paths, in one user-owned folder, `~/.config/local/`.
  - Install creates any missing stub (`nvim.lua`, `tmux.conf`, `bin/`) and never rewrites an
    existing one. `~/.bashrc` stays the shell, prompt and alias override, as it is today.
  - Load order (shared defaults first, override last):
    - Neovim `init.lua` ends by sourcing `~/.config/local/nvim.lua` if it exists.
    - `tmux.conf` ends with `source-file -q ~/.config/local/tmux.conf`.
    - The shared bash file puts `~/.config/local/bin` **before** `~/.config/bin` on PATH.
    - `~/.bashrc` sources the shared file first and runs its own lines afterwards. The template is
      updated to show this order.
- **Rationale**: Keeping overrides outside managed folders means "replace everything we own" can
  never touch user files. That covers Principle IV and the archive-collision edge case, because
  pack never includes `~/.config/local/`.
- **Alternatives**:
  - Merge-copy into managed folders without `rm -rf`. Rejected: stale files linger, and an edit
    to a managed file would look like an override.
  - Per-tool override folders (`~/.config/nvim/local/…`). Rejected because they sit inside
    managed folders.
  - Detect user edits with checksums. Rejected as too complex.

## R4. Pre-requisite check (FR-007, FR-008)

- **Decision**:
  - Install checks the **hard** pre-requisites with `command -v`: `bash`, `git`, `tmux`, `nvim`,
    `fzf`, `tar`, `find`. It collects every missing item, prints the full list, and exits 1 before
    any write.
  - It also checks that every vendored folder is non-empty. If one is empty, it prints
    `git submodule update --init --recursive`.
  - **Optional** tools are only probed: `xsel`/`wl-copy` (Linux clipboard), `direnv`, `jq`,
    `flux`, `talosctl`, `gsettings`, and the `bash-completion` package.
  - The README lists both groups.
- **Rationale**: Fail fast, and report everything in one go (US2-3). Install does not fetch
  submodules itself, so it never needs the network (FR-010).
- **Alternatives**: Auto-run `git submodule update`. Rejected because it needs the network, and
  inside an extracted archive there is no `.git` to run it against.

## R5. Archive format and platform mismatch (FR-015–FR-017, US4-4)

- **Decision**:
  - `pack.sh [output]` writes `dev-sessionizer.tar.gz` by default. The archive has a single
    top-level folder, `dev-sessionizer/`, containing:
    - the repo's installable tree: `env/` including `env/vendor/` without `.git`, `install.sh`,
      `unpack.sh`, `lib.sh`, `README.md`;
    - `runtime/share/nvim/` (with `site/pack/vendor` excluded) and `runtime/state/nvim/`, each
      only if present;
    - `MANIFEST`, which holds `os=<uname -s>`, `arch=<uname -m>` and `created=<ISO date>`.
  - Pack works in a `mktemp -d` folder and removes it with a `trap`.
  - It uses only the `tar -czf` / `tar -xzf` / `-C` flags, which are portable between GNU tar and
    bsdtar.
  - `unpack.sh` runs `install.sh`, then restores runtime state **only when `os` and `arch` match**
    the current machine. On a mismatch it prints a warning naming both platforms and skips runtime
    state.
- **Rationale**: One file, no network, and the unpack script is inside the archive, so the
  target needs nothing extra. Runtime state such as Mason binaries and treesitter parsers is
  native code, so restoring it on another platform would fail silently.
- **Alternatives**:
  - Keep the `bin/unpack` and `bin/update-dev` helpers. Rejected because FR-017 asks for exactly
    one unpack command, and those helpers don't exist on a machine before its first install.
  - Restore mismatched state anyway. Rejected: it would silently break.

## R6. Verification approach (FR-001–FR-003, SC-003)

- **Decision**: `tests/verify.sh [lint|mac|linux|all]`, plain bash with no test framework.
  - **lint**: run `bash -n` on every shipped script, then `shellcheck -s bash` on them. Use the
    local `shellcheck` if it is installed; otherwise run the `koalaman/shellcheck-alpine` container.
    Add a grep gate for known one-platform constructs (`sed -i`, `readlink -f`, `date -d`,
    `realpath`, `grep -P`), unless the line is annotated `# portable-ok`.
  - **Smoke test** (`tests/smoke.sh`): run against `HOME=$(mktemp -d)`. It aborts if `HOME`
    equals the real home. Scenarios:
    - install;
    - install again and compare file checksums of the managed paths;
    - create overrides, install again, and assert they are unchanged and loaded;
    - with a pre-requisite stripped from PATH, install fails and writes nothing;
    - pack, then unpack into a fresh home;
    - Neovim headless start with no errors (`nvim --headless "+qa"`, stderr checked);
    - load the tmux config on a private socket (`-L verify`);
    - an interactive bash start sets the prompt.
  - **mac**: run the smoke test natively, starting the entry scripts with `/bin/bash` (3.2) so the
    bash 3.2 constraint is actually exercised.
  - **linux**: build `tests/Dockerfile` (debian stable-slim with the pre-requisites) and run the
    smoke test inside it. The unpack step runs in a second container with `--network none`.
  - **CI**: `.github/workflows/verify.yml` runs `lint` and `linux` on `ubuntu-latest`, and `mac` on
    `macos-latest`, for pushes and PRs.
- **Rationale**: This is the smallest thing that satisfies "verify on both platforms" without a
  new language (Principle V). `--network none` proves the offline claim on Linux. CI gives a
  reliable macOS run and enforces the Development Workflow rule.
- **Alternatives**:
  - bats-core. Rejected: an extra vendored dependency for roughly 10 assertions.
  - A macOS VM for local checks. Rejected as too heavy; the maintainer's own Mac plus CI is
    enough.
  - Proving the offline claim on macOS. Accepted gap: macOS has no cheap network sandbox, so
    the Linux `--network none` run carries that claim.

## R7. Project picker (FR-019–FR-022)

- **Decision**: Rewrite `bin/dev` as the only session tool and delete `claude-session`.
  - **Roots file** `~/.devconfig`:
    - one folder per line; `#` comments and blank lines are ignored;
    - a leading `~` and `$VAR` / `${VAR}` are expanded with bash string handling and
      `BASH_REMATCH`, never `eval`;
    - roots that don't exist are skipped.
  - **Session name**: the folder's basename with every character outside `[A-Za-z0-9_-]` replaced
    by `_`.
    - If a session with that name already exists **for the same path**, switch to it.
    - If it exists for a different path, append `_<parent basename>`.
  - Inside tmux it uses `switch-client`; outside tmux it uses `attach`.
  - If the roots file, `fzf` or `tmux` is missing, it prints the fix and exits 1. Cancelling the
    picker exits 0.
- **Rationale**:
  - A deterministic name gives "open or switch" semantics, where today every run creates a
    duplicate session.
  - The sanitised name is always a valid tmux target.
  - Removing `eval` closes the code-execution path.
  - `openssl` is dropped as a dependency.
- **Alternatives**:
  - Keep random suffixes. Rejected: duplicate sessions, and `/` or `+` in names.
  - `envsubst` for expansion. Rejected: not on stock macOS.

## R8. Vendoring consistency (FR-026)

- **Decision**: Convert `env/vendor/oh-my-bash` from plain tracked files into a pinned git
  submodule, like the Neovim plugins. Pin it to the upstream commit that best matches the tracked
  files, and record it in the commit message. The `.gitmodules` entry stays.
- **Rationale**: Every vendored dependency then uses one mechanism and one update workflow, the
  one in the README.
- **Alternatives**: Keep the copied files and drop the `.gitmodules` entry. Rejected: there would
  be two vendoring styles, and updates would be manual copies.

## R9. Removals and clean-ups (FR-021, FR-024, FR-025, FR-014)

- **Decision**: Delete the following:
  - `env/.config/ai/` (runner, build, init, Dockerfile, README), its install step and its PATH
    entry;
  - `env/.config/bin/{claude-session,kubectx-create,unpack,update-dev,go-task}`;
  - the `ifi` alias;
  - `env/.config/nvim/lsp/` (373 files), since `diff` shows the 5 enabled configs are older
    unmodified copies of the vendored nvim-lspconfig;
  - `env/.config/nvim/nvim-pack-lock.json`;
  - `Taskfile.yaml`;
  - the `ghcr-io-s1monb-dev*` ignore entry.
- **Rationale**: Principle V, and the user's clarifications.

## R10. Smaller portability fixes

- **tmux shell**: `default-command /bin/bash` launches bash 3.2 on macOS. Change it to
  `default-command "exec bash"` so the bash on PATH is used (Homebrew bash 5 on macOS).
- **Clipboard on Linux**: use `wl-copy` when `$WAYLAND_DISPLAY` is set, otherwise `xsel -i -b`.
- **PATH**: drop the hard-coded linuxbrew path. Instead, run `brew shellenv` from whichever of
  `/opt/homebrew`, `/usr/local` or `/home/linuxbrew/.linuxbrew` exists.
- **`esc-caps-swap`**: exit 1 with "requires GNOME (gsettings)" unless `gsettings` is available and
  `$XDG_CURRENT_DESKTOP` contains `GNOME`.
- **Docs**: use one vocabulary (install / pack / unpack) across README, `CONTEXT.md` and
  `.bashrc.example`, and remove the stale `install-locally` name.
