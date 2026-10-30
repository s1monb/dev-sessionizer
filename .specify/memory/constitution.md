# Dev-sessionizer Constitution

## Core Principles

### I. Portable Across macOS and Linux

Every tool, script, and config shipped by this repo MUST work on both macOS and Linux
without edits.

- Scripts MUST avoid GNU-only or BSD-only flags (e.g. `sed -i`, `readlink -f`, `date -d`)
  unless guarded by a platform check or replaced with a portable equivalent.
- Platform-specific behaviour MUST be isolated in one clearly marked branch
  (`uname`-based), never scattered through a script.
- Optional external tools (e.g. `flux`, `talosctl`) MUST be detected with `command -v` and
  skipped gracefully when absent; their absence MUST NOT fail an install.

Rationale: the toolkit exists to give the same environment on many different machines.

### II. One-Command Install and Update

A fresh machine MUST reach a working environment from a clone with a single documented
command, and the same command MUST perform an update.

- Install MUST be idempotent: running it twice yields the same result as running it once.
- Install MUST only touch paths it owns (repo-managed directories under `$HOME/.config`,
  `$HOME/.local/share/nvim/site/pack/vendor`, and documented equivalents).
- Pre-requisites MUST be listed in the README; install MUST fail fast with a clear message
  when a hard pre-requisite is missing.

Rationale: setting up or refreshing a machine should take seconds, not a checklist.

### III. Transferable via Files

The full environment MUST be movable to another machine, including airgapped ones, using
only files.

- Third-party code required at runtime MUST be vendored under `env/vendor/` (pinned
  submodules or copied sources); install MUST NOT require network access after clone.
- Pack MUST produce a single archive containing everything needed; unpack on the target MUST
  restore a working environment with no outbound network.
- Runtime state that cannot be rebuilt offline (LSP binaries, parsers) MUST be carried by
  pack.

Rationale: some target machines have no internet; files are the lowest common denominator.

### IV. Overwriteable by Design

Repo-managed files are replaceable; machine-local customisation is never lost.

- Files the repo owns MAY be overwritten wholesale on every install; users MUST NOT be
  expected to edit them in place.
- Every component that users plausibly customise (shell, prompt, aliases, editor, tmux)
  MUST offer a local override point that the repo never writes after first creation
  (e.g. `~/.bashrc`) and that is loaded after the shared defaults so it wins.
- Install MUST NOT overwrite a user-owned file that already exists.

Rationale: shared defaults stay updatable while each machine keeps its own quirks.

### V. Minimal and Simple

The toolkit ships only what is actually used, implemented in the simplest form that works.

- New tools, dependencies, or plugins MUST have a concrete current use; unused items MUST
  be removed.
- Prefer plain bash and the existing task runner over new languages or frameworks; adding
  one requires justification in the plan's Complexity Tracking.
- Scripts SHOULD be short, single-purpose, and readable without comments explaining
  clever tricks; `set -euo pipefail` (or equivalent) MUST be used in standalone scripts.

Rationale: a small codebase is easy to trust, port, and carry between machines.

## Technical Constraints

- Shell: bash is the supported login and scripting shell; scripts MUST run on the bash
  versions shipped with current macOS (via Homebrew) and mainstream Linux distributions.
- Entry points: the root-level scripts `install.sh` (install and update), `pack.sh` and
  `unpack.sh` are the only entry points. No task runner is required or shipped. Shared logic
  lives in a single sourced helper (`lib.sh`), and the entry scripts MUST run on bash 3.2 (stock
  macOS) so that a fresh or airgapped machine needs nothing extra.
- Layout: deployable config lives under `env/`, mirroring its destination under `$HOME`;
  vendored third-party code lives under `env/vendor/`.
- Vocabulary: terms defined in `CONTEXT.md` (Vendor, Install, Pack, Unpack, Runtime state,
  Plugin, Airgapped environment) MUST be used consistently in code, docs, and specs.

## Development Workflow

- Every change affecting install, pack, or unpack MUST be exercised on at least one macOS
  and one Linux environment (a container counts for Linux) before merge.
- README MUST be updated in the same change when install steps, pre-requisites, or override
  points change.
- Commits follow conventional prefixes (`feat:`, `fix:`, `chore:`, `docs:`, `vendor:`).
- Vendored dependency updates MUST pin an explicit commit.

## Governance

This constitution supersedes other conventions in the repo. Specs, plans, and reviews MUST
check compliance with the Core Principles; any deviation MUST be justified in the plan's
Complexity Tracking or rejected.

- Amendments are made via `/speckit-constitution`, recorded in a commit that states the
  version change and rationale.
- Versioning: MAJOR for removing or redefining a principle, MINOR for adding a principle or
  section or materially expanding guidance, PATCH for clarifications and wording.
- Compliance review: each `/speckit-plan` Constitution Check gate MUST evaluate all five
  principles.

**Version**: 1.1.0 | **Ratified**: 2026-10-30 | **Last Amended**: 2026-10-30
