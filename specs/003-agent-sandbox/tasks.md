---

description: "Task list for the agent sandbox"
---

# Tasks: Agent Sandbox

**Input**: Design documents from `/specs/003-agent-sandbox/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/cli.md, quickstart.md

**Tests**: Included. The plan (research.md R12) and the constitution workflow require coverage in
`tests/smoke.sh`. Write each story's scenarios first and confirm they fail before implementing.

**Organization**: Tasks are grouped by user story so each story can be implemented and tested on
its own.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: The user story the task belongs to (US1–US5)

## Path Conventions

- New command: `env/.config/bin/sandbox`, deployed to `~/.config/bin/sandbox` by `install.sh`.
- New image files: `env/.config/sandbox/Dockerfile` and `env/.config/sandbox/entrypoint.sh`,
  deployed to `~/.config/sandbox/`.
- Tests: `tests/smoke.sh`. Scenarios are auto-discovered by the `scenario_` prefix. Docker scenarios
  are named `scenario_agent_*` and run only via `tests/verify.sh sandbox` (`DS_DOCKER_TESTS=1`).
- Host-side bash (`sandbox`, `install.sh`, `lib.sh`, tests) MUST run on bash 3.2 under
  `set -euo pipefail`. No `readlink -f`, `realpath`, `sha256sum`, `mapfile` or `declare -A`
  (`tests/verify.sh lint` enforces this). The entrypoint runs only in the Debian image, but keep it
  shellcheck-clean.

---

## Phase 1: Setup

**Purpose**: Confirm a clean baseline on the feature branch

- [X] T001 On branch `003-agent-sandbox`, run `tests/verify.sh lint` and `tests/verify.sh mac` and
  confirm both pass before any change (no repo files change)

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Install wiring, the verify target and the Docker test gate that every story needs

- [X] T002 [P] Add `"$HOME/.config/sandbox"` to the `ds_managed` list in `lib.sh`, after
  `"$HOME/.config/bin"`
- [X] T003 Edit `install.sh`:
  - add `replace "$ENV/.config/sandbox" "$HOME/.config/sandbox"` after the `bin` line;
  - in the overrides block, create `~/.config/local/sandbox.env` only if missing, then
    `chmod 600` it. Content: a comment saying it is read by `sandbox` as Docker `--env-file`
    (`KEY=value` per line, no quotes, never sourced, never touched by install), and a commented
    example `# CLAUDE_CODE_OAUTH_TOKEN=` with a note to fill it from `claude setup-token`.

  (Depends on T002 only for `ds_managed` consistency in tests.)
- [X] T004 [P] Create an empty placeholder `env/.config/sandbox/` with `Dockerfile` and
  `entrypoint.sh` stubs (`#!/usr/bin/env bash` + `set -euo pipefail` for the entrypoint, mode 755),
  so install and lint have something to deploy. US1 fills them in.
- [X] T005 Edit `tests/verify.sh`:
  - add `env/.config/sandbox/entrypoint.sh` to `shipped_scripts`;
  - add a `sandbox` target. It fails with "docker not found" when Docker is missing. Otherwise it
    runs `DS_DOCKER_TESTS=1 bash tests/smoke.sh <names>`, where `<names>` are the
    `scenario_agent_*` function names grepped from `tests/smoke.sh`. It reports PASS or FAIL like
    `target_mac`, and passes `SANDBOX_NETWORK` through from the environment;
  - add it to `usage` and the `case`, but not to `all`.
- [X] T006 Add a harness helper section `# --- agent sandbox ---` to `tests/smoke.sh` with:
  - `needs_docker`: when `DS_DOCKER_TESTS` is not `1`, prints `ok # skip (DS_DOCKER_TESTS=1 to run)`
    and returns 1, so each scenario starts with `needs_docker || return 0`. Otherwise it exports
    `DOCKER_CONFIG="$DS_REAL_HOME/.docker"`.
  - `sandbox_cmd`: runs `"$DS_BASH" "$HOME/.config/bin/sandbox" "$@"`.
  - `new_project`: creates `$HOME/proj` (mktemp-unique) as a git repo with one commit and prints its
    `pwd -P` path.
  - `drop_cache DIR`: runs `sandbox --reset shell DIR -- -c true` and ignores the result, so
    scenarios clean up their volume.

**Checkpoint**: `./install.sh` deploys the new paths. `tests/verify.sh sandbox` runs and every
agent scenario reports skipped or none exist yet. Lint passes.

---

## Phase 3: User Story 1 - Run an agent on a project without prompts, safely (Priority: P1) 🎯 MVP

**Goal**: `sandbox [DIR]` starts Claude Code with prompts off in a hardened throwaway container
that can write only to the project, as the host user. `shell` mode is built here too, because the
tests drive the sandbox through it.

**Independent Test**: quickstart.md Manual step 1; `scenario_sandbox_*` and
`scenario_agent_isolation` pass.

### Tests for User Story 1 (write first, confirm they fail)

- [X] T007 [P] [US1] Add `scenario_sandbox_install` to `tests/smoke.sh`:
  - after install, `~/.config/bin/sandbox` is executable and `~/.config/sandbox/Dockerfile` and
    `entrypoint.sh` exist;
  - `~/.config/local/sandbox.env` exists with mode 600. Check with `ls -l` and match `-rw-------`,
    portable across macOS and Linux;
  - after appending a line to `sandbox.env` and re-running install, the line is still there.

  Update `scenario_helpers` so the expected helper list is `"dev dev-gc esc-caps-swap sandbox "`.
- [X] T008 [P] [US1] Add `scenario_sandbox_refusals` to `tests/smoke.sh` (no Docker needed). Each
  case must exit 1 with a `sandbox:` message on stderr:
  - `sandbox "$HOME"`;
  - `sandbox /`;
  - `sandbox "$(dirname "$HOME")"` (an ancestor of HOME);
  - `sandbox "$HOME/missing"`;
  - `sandbox --bogus`;
  - `sandbox codex` with no `codex` folder: the message lists `claude, opencode, shell`;
  - `sandbox a b` (two folders).

  Then `env PATH=/usr/bin:/bin "$DS_BASH" ~/.config/bin/sandbox "$HOME/p"` with `$HOME/p` created
  first must fail with `docker not found`. Skip only this case with `ok # skip` when
  `/usr/bin/docker` or `/bin/docker` exists. Also `sandbox --help` exits 0 and prints `Usage`.
- [X] T009 [P] [US1] Add `scenario_agent_isolation` to `tests/smoke.sh` (starts with
  `needs_docker || return 0`). Set up with `new_project` and `export SSH_AUTH_SOCK=/tmp/fake.sock`,
  then run one `sandbox_cmd shell "$proj" -- -c '…'` that prints lines checked with
  `assert_contains`:
  - `id -u`/`id -g` equal the host's;
  - `pwd` equals `$proj`;
  - `grep CapEff /proc/self/status` is all zeros;
  - `grep NoNewPrivs` shows `1`;
  - `command -v sudo` prints nothing;
  - `/var/run/docker.sock` and `/run/docker.sock` are absent;
  - `SSH_AUTH_SOCK` is unset;
  - `touch /etc/x`, `touch "$(dirname "$proj")/outside"` and `touch /host/x` all fail;
  - `claude --version` succeeds.

  Inside the same run, `echo hi > made && git add made && git commit -qm sbx`, then
  `git push https://github.com/s1monb/dev-sessionizer.git HEAD:refs/heads/sbx-test` must fail.

  On the host afterwards:
  - `made` is owned by the host UID (`ls -ln`);
  - `git log -1 --format=%an` equals the host `git config user.name` when set;
  - `"$(dirname "$proj")/outside"` does not exist;
  - `docker ps -aq --filter ancestor=dev-sessionizer-sandbox` is empty.

  Finish with `drop_cache "$proj"`.

### Implementation for User Story 1

- [X] T010 [P] [US1] Write `env/.config/sandbox/Dockerfile` (research R3, R7, R8, R11):
  - `FROM debian:stable-slim` with `ARG UID` and `ARG GID`.
  - `apt-get install -y --no-install-recommends git ca-certificates curl ripgrep jq less procps unzip
    xz-utils zip build-essential`, then remove the apt lists. No sudo.
  - `git config --system safe.directory '*'`.
  - Group: reuse the group with `$GID` if `getent group "$GID"` finds one, else `groupadd -g "$GID"
    agent`. User: `useradd -m -d /home/agent -u "$UID" -g "$GID" -s /bin/bash agent`. If that UID
    already exists, fail with a message naming the UID.
  - `mkdir /cache && chown "$UID:$GID" /cache`.
  - `ENV LANG=C.UTF-8 DISABLE_AUTOUPDATER=1 GIT_TERMINAL_PROMPT=0 MISE_DATA_DIR=/cache/mise
    XDG_CACHE_HOME=/cache/xdg npm_config_cache=/cache/npm GOPATH=/cache/go CARGO_HOME=/cache/cargo
    PATH=/cache/mise/shims:/home/agent/.local/bin:/home/agent/.opencode/bin:$PATH`.
  - `USER agent`, then run the installers: `curl -fsSL https://claude.ai/install.sh | bash`,
    `curl -fsSL https://opencode.ai/install | bash`, `curl -fsSL https://mise.run | sh`. Verify with
    `claude --version && opencode --version && mise --version`.
  - `COPY entrypoint.sh /usr/local/bin/sandbox-entrypoint` (chmod 755 via `COPY --chmod=755`),
    `WORKDIR /home/agent`, `ENTRYPOINT ["sandbox-entrypoint"]`.
- [X] T011 [P] [US1] Write `env/.config/sandbox/entrypoint.sh`, first version. Usage:
  `sandbox-entrypoint MODE [ARGS...]`, mapping:
  - `claude` → `exec claude --dangerously-skip-permissions "$@"`
  - `opencode` → `exec opencode --auto "$@"`
  - `shell` → `exec bash "$@"`
  - anything else → message to stderr, exit 2.

  Leave clearly marked spots, as comments, for the config copy (US2) and mise install (US4) before
  the `exec`.
- [X] T012 [US1] Write `env/.config/bin/sandbox`, part 1: argument parsing and validation
  (contracts/cli.md, data-model.md "Project path validation"):
  - `#!/usr/bin/env bash`, `set -euo pipefail`, a `usage` heredoc, and `die() { printf 'sandbox:
    %s\n' "$*" >&2; exit 1; }`.
  - Parse `--network MODE`, `--rebuild`, `--reset`, `-h|--help` and `--` (the rest go into an args
    array) in any position. The first positional matching `claude|opencode|shell` is the mode
    (default `claude`). Any other positional is DIR, at most one.
  - If a positional is neither a mode nor an existing folder: `die "unknown agent or folder: X
    (agents: claude, opencode, shell)"`.
  - Resolve with `project="$(cd "$dir" && pwd -P)"` and `home="$(cd "$HOME" && pwd -P)"`. Refuse
    when `project` is `/`, equals `home`, or `home` starts with `$project/`. Refuse when
    `id -u` is 0.
  - Only then check `command -v docker`: `die "docker not found; install Docker to use the
    sandbox"`. Then `docker info >/dev/null 2>&1 || die "cannot reach the Docker daemon"`.
- [X] T013 [US1] `env/.config/bin/sandbox`, part 2: the image (research R2):
  - `files="$(cd "$(dirname "${BASH_SOURCE[0]}")/../sandbox" && pwd -P)"`.
  - `hash="$(cat "$files/Dockerfile" "$files/entrypoint.sh" | cksum | cut -d' ' -f1)-$(id
    -u)-$(id -g)"`.
  - Compare with `docker image inspect -f '{{ index .Config.Labels "dev-sessionizer.hash" }}'
    dev-sessionizer-sandbox 2>/dev/null`.
  - When it differs, the image is missing, or `--rebuild` is set, run `docker build -t
    dev-sessionizer-sandbox --label "dev-sessionizer.hash=$hash" --build-arg UID="$(id -u)"
    --build-arg GID="$(id -g)" "$files"`, adding `--pull --no-cache` for `--rebuild`. On failure,
    `die "image build failed"`. Print build progress to stderr only.
- [X] T014 [US1] `env/.config/bin/sandbox`, part 3: run (research R4, R9, R10, R11; data-model.md
  session mounts):
  - Volume name: `dev-sessionizer-sandbox-<name>-<crc>`. `<name>` is
    `basename "$project" | tr -c 'A-Za-z0-9_.-\n' '-'`, and `<crc>` is the first field of
    `printf %s "$project" | cksum`.
  - `--reset` → `docker volume rm -f "$volume" >/dev/null`.
  - Build the run arguments in an array: `run --rm -i --init --cap-drop=ALL
    --security-opt=no-new-privileges --pids-limit=4096 --hostname sandbox
    --network "${network:-${SANDBOX_NETWORK:-bridge}}" -v "$project:$project" -w "$project" -v
    "$volume:/cache"`.
  - Add `-t` when `[[ -t 0 && -t 1 ]]`.
  - Add `-e NAME` for each of `CLAUDE_CODE_OAUTH_TOKEN ANTHROPIC_API_KEY TERM COLORTERM` that is set.
  - Git identity: `-e GIT_AUTHOR_NAME=… -e GIT_COMMITTER_NAME=…` from `git config --get user.name`,
    and the same for email, when non-empty.
  - Add `--env-file ~/.config/local/sandbox.env` when the file exists.
  - Finish with `dev-sessionizer-sandbox "$mode" "${args[@]}"`, using bash 3.2-safe empty-array
    expansion `${args[@]+"${args[@]}"}`.
  - End with `exec docker "${run[@]}"`.
- [ ] T015 [US1] Run `tests/smoke.sh scenario_sandbox_install scenario_sandbox_refusals
  scenario_helpers` and `tests/verify.sh sandbox`, and fix until US1 scenarios pass. Then do
  quickstart.md Manual step 1 by hand with a real Claude login and confirm Claude Code starts with no
  bypass-permissions or trust prompt. If a prompt appears, record what was needed (for example a
  `~/.claude.json` key set by the entrypoint) in research.md R7.
  - Status: automated part done (`scenario_sandbox_*`, `scenario_agent_isolation` pass). The
    manual real-login check is **open**: no Claude token was available in the implementing
    session. The author must run `sandbox` once with `CLAUDE_CODE_OAUTH_TOKEN` in `sandbox.env`.

**Checkpoint**: MVP. A prompt-free, hardened Claude Code session on one project, owned files, no
push.

---

## Phase 4: User Story 2 - The agent uses the developer's own config (Priority: P1)

**Goal**: Host Claude Code and OpenCode config and logins are visible to the agent, copied from
read-only mounts, with session history excluded and host files untouched.

**Independent Test**: `scenario_agent_config` passes; quickstart.md Manual step 2.

### Tests for User Story 2

- [X] T016 [US2] Add `scenario_agent_config` to `tests/smoke.sh` (`needs_docker || return 0`).
  Fake host config in the throwaway `HOME`:
  - `~/.claude/settings.json` (`{"marker":1}`), `~/.claude/CLAUDE.md` (`MARKER-CLAUDE`),
    `~/.claude/projects/p/t.jsonl`, `~/.claude/history.jsonl` and `~/.claude/.credentials.json`;
  - `~/.claude.json` (`{"hasCompletedOnboarding":true}`);
  - `~/.config/opencode/opencode.jsonc` and `~/.config/opencode/node_modules/x/index.js`;
  - `~/.local/share/opencode/auth.json`.

  Put `FROM_ENVFILE=yes` in `~/.config/local/sandbox.env`. Export `CLAUDE_CODE_OAUTH_TOKEN=tok` and
  `UNRELATED_SECRET=nope`. Record `checksum_tree ~/.claude` plus `cksum` of the three files. In one
  `sandbox_cmd shell` run, assert:
  - `~/.claude/CLAUDE.md` contains `MARKER-CLAUDE`;
  - `~/.claude.json`, `~/.config/opencode/opencode.jsonc` and
    `~/.local/share/opencode/auth.json` exist;
  - `~/.claude/projects`, `~/.claude/history.jsonl`, `~/.claude/.credentials.json` and
    `~/.config/opencode/node_modules` are absent;
  - `echo '{}' > ~/.claude/settings.json` succeeds;
  - `echo x >> /host/claude/settings.json` fails;
  - `$CLAUDE_CODE_OAUTH_TOKEN` is `tok`, `$FROM_ENVFILE` is `yes`, and `UNRELATED_SECRET` is unset.

  Afterwards the host checksums are unchanged (SC-004). Then remove every config file and confirm
  `sandbox_cmd shell "$proj" -- -c true` still exits 0. Finish with `drop_cache`.

### Implementation for User Story 2

- [X] T017 [US2] In `env/.config/bin/sandbox`, add read-only mounts only for sources that exist
  (`[[ -e ]]`):
  - `"$HOME/.claude:/host/claude:ro"`
  - `"$HOME/.claude.json:/host/claude.json:ro"`
  - `"$HOME/.config/opencode:/host/opencode-config:ro"`
  - `"$HOME/.local/share/opencode/auth.json:/host/opencode-auth.json:ro"`
- [X] T018 [US2] In `env/.config/sandbox/entrypoint.sh`, at the config spot, copy each `/host`
  source that exists into `$HOME` (research R5):
  - `/host/claude` → `~/.claude`, via `tar -C /host/claude -cf - --exclude=./projects
    --exclude=./file-history --exclude=./history.jsonl --exclude=./sessions --exclude=./session-env
    --exclude=./shell-snapshots --exclude=./paste-cache --exclude=./cache --exclude=./backups
    --exclude=./todos --exclude=./statsig --exclude=./debug --exclude=./ide
    --exclude=./.credentials.json . | tar -C ~/.claude -xf -`;
  - `/host/claude.json` → `~/.claude.json`;
  - `/host/opencode-config` → `~/.config/opencode` (excluding `./node_modules`);
  - `/host/opencode-auth.json` → `~/.local/share/opencode/auth.json` (mode 600).

  Make the copies writable by the user (`chmod -R u+w`).
- [X] T019 [US2] Run `tests/verify.sh sandbox` until `scenario_agent_config` passes, then do
  quickstart.md Manual step 2

**Checkpoint**: The agent sees the developer's settings and login; host config is unchanged after
any session.

---

## Phase 5: User Story 3 - Choose OpenCode instead of Claude Code (Priority: P2)

**Goal**: `sandbox opencode` starts OpenCode with no permission prompts and the inherited config.

**Independent Test**: `scenario_agent_opencode` passes; quickstart.md Manual step 3.

- [X] T020 [US3] Add `scenario_agent_opencode` to `tests/smoke.sh` (`needs_docker || return 0`):
  - `sandbox_cmd opencode "$proj" -- --version` exits 0;
  - `sandbox_cmd shell "$proj" -- -c 'opencode --help 2>&1'` contains `--auto`. This is the check
    for research R7.

  Finish with `drop_cache`.
- [ ] T021 [US3] If `--auto` is missing from the installed OpenCode, switch the entrypoint's
  `opencode` mapping to the documented alternative: set `OPENCODE_CONFIG_CONTENT='{"permission":
  "allow"}'` if that variable is supported, else write `"permission": "allow"` into the session's
  `~/.config/opencode/opencode.json`. Record the outcome in research.md R7. Otherwise no change. Run
  the scenario until it passes, then do quickstart.md Manual step 3 with a real provider login.
  - Status: `--auto` exists in OpenCode 1.19.5 (`scenario_agent_opencode`), so no fallback was
    needed. The manual check with a real provider login is **open** for the author.

**Checkpoint**: Both agents work with the same isolation.

---

## Phase 6: User Story 4 - Project toolchains are ready and fast to restart (Priority: P2)

**Goal**: mise tools declared by the project are installed at start and cached per project.
`--reset` and `--rebuild` work.

**Independent Test**: `scenario_agent_cache` passes; quickstart.md Manual step 4.

- [X] T022 [US4] Add `scenario_agent_cache` to `tests/smoke.sh` (`needs_docker || return 0`):
  - Write `.tool-versions` with `shfmt 3.10.0` in a new project.
  - `sandbox_cmd shell "$proj" -- -c 'shfmt --version'` prints `v3.10.0`.
  - The same command with `--network none` still prints `v3.10.0`, showing nothing is downloaded
    (SC-005).
  - After `sandbox_cmd --reset shell "$proj" -- -c true`,
    `sandbox_cmd --network none shell "$proj" -- -c 'shfmt --version'` fails or warns.
  - A second project does not see the first project's shfmt (separate volume).
  - A project whose `.tool-versions` names a non-existent version still starts the shell: exit 0,
    with a warning on stderr.

  Finish with `drop_cache` for both.
- [X] T023 [US4] In `env/.config/sandbox/entrypoint.sh`, at the mise spot: when `$PWD` has
  `mise.toml`, `.mise.toml` or `.tool-versions`, run `MISE_TRUSTED_CONFIG_PATHS="$PWD" mise install
  --yes`, then `export MISE_TRUSTED_CONFIG_PATHS="$PWD"` for the session. On failure, print
  `sandbox: mise install failed; starting anyway` to stderr and continue (FR-015). Confirm the
  `--reset` and `--rebuild` handling from T013/T014 behaves as in contracts/cli.md
- [X] T024 [US4] Run `tests/verify.sh sandbox` until `scenario_agent_cache` passes, then do
  quickstart.md Manual steps 4 and 6 (start time under 5 s)

**Checkpoint**: Toolchains ready, second starts offline-fast, cache resettable.

---

## Phase 7: User Story 5 - Debug the sandbox from a shell (Priority: P3)

**Goal**: `sandbox shell` gives the agent's exact environment interactively.

**Independent Test**: `scenario_agent_shell` passes; run `sandbox shell` by hand.

- [X] T025 [US5] Add `scenario_agent_shell` to `tests/smoke.sh` (`needs_docker || return 0`).
  Check that `sandbox_cmd shell "$proj" -- -c 'echo $HOME; pwd; id -un'` prints `/home/agent`,
  `$proj` and `agent`, and that its exit status passes through: `-- -c 'exit 7'` exits 7. Finish
  with `drop_cache`. Run `sandbox shell` interactively once and confirm a TTY prompt.

**Checkpoint**: All user stories complete.

---

## Phase 8: Polish & Cross-Cutting Concerns

- [X] T026 [P] Add an "Agent sandbox" section to `README.md`. Also add Docker under optional
  prerequisites as needed for `sandbox`, and add `~/.config/local/sandbox.env` to the overrides
  table. The section covers:
  - usage and options (contracts/cli.md);
  - what is isolated and what is not: full internet; the agent can change `.git` hooks and config,
    which run on the host and do not show in a diff (FR-006a); review project changes before running
    them on the host; remote URLs with embedded tokens; worktrees don't work; dangling symlinked
    config; rotating OpenCode OAuth logins;
  - the macOS login via `claude setup-token` into `sandbox.env`;
  - `SANDBOX_NETWORK` for Linux hosts whose bridge has no internet;
  - that `sandbox` needs network and does not work airgapped.
- [X] T027 [P] Add an **Agent sandbox** term to `CONTEXT.md`: "A throwaway container started by
  `sandbox` in which a coding agent runs without permission prompts. It can write only to one
  project folder." Add `_Avoid_: sandbox (alone), which in tests means the throwaway HOME used by
  smoke scenarios`.
- [X] T028 Run `tests/verify.sh lint`, `tests/verify.sh mac`, `tests/verify.sh linux` and
  `tests/verify.sh sandbox` on macOS; all must PASS
- [ ] T029 Ask the author to run `SANDBOX_NETWORK=host tests/verify.sh sandbox` on their Linux host
  (constitution workflow: macOS and Linux before merge) and record the result in this file
  - Status: **open**. It needs the author's Linux host.
- [X] T030 Mark completed tasks `[X]` here and tick `checklists/requirements.md` if anything changed

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: none.
- **Foundational (Phase 2)**: after Setup. Blocks all stories.
- **US1 (Phase 3)**: after Foundational. Blocks US2–US5, which extend the files it creates
  (`sandbox`, `entrypoint.sh`, `Dockerfile`).
- **US2, US3, US4 and US5**: each depends only on US1. US2 and US4 both edit `entrypoint.sh` at
  separate marked spots, so they can be done in either order but not at the same moment.
- **Polish (Phase 8)**: after the desired stories.

### Within Each Story

- Write the scenarios first and see them fail (or skip without `DS_DOCKER_TESTS=1`).
- `sandbox` parts 1 → 2 → 3 are sequential (same file).
- Run the story's checkpoint before moving on.

### Parallel Opportunities

- T002 and T004 in Phase 2.
- T007, T008 and T009 (tests), then T010 and T011 (Dockerfile, entrypoint) in US1, while T012–T014
  are written sequentially.
- T026 and T027 in Polish.

## Parallel Example: User Story 1

```text
Task: "T007 scenario_sandbox_install in tests/smoke.sh"
Task: "T010 Dockerfile in env/.config/sandbox/Dockerfile"
Task: "T011 entrypoint in env/.config/sandbox/entrypoint.sh"
```

(The three tests T007–T009 all edit `tests/smoke.sh`. Mark them [P] only if they are written as
separate, non-overlapping additions.)

## Implementation Strategy

### MVP First (User Story 1)

1. Phases 1–2.
2. Phase 3 → validate with `tests/verify.sh sandbox` and quickstart.md step 1.
3. Stop and use it: this already gives a safe, prompt-free Claude Code. Login works through the
   token in `sandbox.env` (T014). Host settings and CLAUDE.md arrive with US2.

### Incremental Delivery

1. US1 → MVP.
2. US2 → inherited config and logins (the second P1; do it right after).
3. US3 → OpenCode.
4. US4 → toolchains and cache.
5. US5 → shell check.
6. Polish → README, CONTEXT.md, full verification on both platforms.
