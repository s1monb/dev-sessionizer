---
description: "Task list for 004 Offline Sandbox Image and Default Agent"
---

# Tasks: Offline Sandbox Image and Default Agent

**Input**: Design documents from `specs/004-offline-sandbox-image/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/pack-unpack.md,
contracts/sandbox.md, quickstart.md

**Tests**: Requested by the spec (SC-004). Smoke scenarios use a fake `docker` on `PATH` so they
run in `tests/verify.sh mac` and `linux` without Docker. One real-Docker scenario runs under
`tests/verify.sh sandbox`. Within each story, write its scenarios first and see them fail.

**Organization**: Grouped by user story (spec.md). US1 and US2 are both P1 and together make the
MVP: US1 alone produces an archive, and US2 makes it usable.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1–US4)

## Conventions for every task

- Host scripts (`pack.sh`, `unpack.sh`, `lib.sh`, `env/.config/bin/sandbox`) MUST run on bash 3.2:
  no `declare -A`, no `${var,,}`, no `mapfile`, no `readlink -f`, no `sed -i` without a suffix.
- Messages: `pack.sh`/`unpack.sh` use `ds_log`/`ds_err` (prefix `dev-sessionizer:`); `sandbox` uses
  its own `die` (prefix `sandbox:`).
- Smoke scenarios go in `tests/smoke.sh`, named `scenario_*`, use `new_sandbox`, `install`,
  `assert_ok`/`assert_fail`/`assert_eq`/`assert_contains`/`assert_not_contains`, and read
  `$DS_RUN/out` / `$DS_RUN/err` after `assert_*`. Real-Docker ones start with `needs_docker || return 0`
  and are named `scenario_agent_*`.

---

## Phase 1: Setup

**Purpose**: The fake `docker` used by every new non-Docker scenario.

- [X] T001 Create `tests/fake-docker` (bash, `set -euo pipefail`, executable). It appends `"$*"` as
  one line to `$FAKE_DOCKER_LOG` and answers by first argument(s):
  - `info`: exit `${FAKE_DOCKER_INFO_RC:-0}`.
  - `image inspect -f FORMAT NAME`: exit 1 when `FAKE_DOCKER_IMAGE` is empty. Otherwise print the
    value for the label named in FORMAT: `dev-sessionizer.packed`→`$FAKE_DOCKER_PACKED`,
    `.uid`→`$FAKE_DOCKER_UID`, `.gid`→`$FAKE_DOCKER_GID`, `.files`→`$FAKE_DOCKER_FILES`,
    `.hash`→`$FAKE_DOCKER_HASH`, `.Architecture`→`${FAKE_DOCKER_ARCH:-amd64}`. When FORMAT asks
    for several values, print them joined by `|` in the order asked, keeping empty values (e.g.
    `||||abc-1000-1000` for a local image), the same output real Docker gives for the T017 format.
  - `build`: exit `${FAKE_DOCKER_BUILD_RC:-0}`.
  - `save`: write the text `fake-image` to the path after `-o`, exit `${FAKE_DOCKER_SAVE_RC:-0}`.
  - `save --help`: print a usage that contains `--platform` unless `FAKE_DOCKER_NO_SAVE_PLATFORM=1`.
  - `load`: exit `${FAKE_DOCKER_LOAD_RC:-0}`.
  - `tag`, `image rm`, `volume …`: exit 0.
  - `run`: print `RUN $*` on stdout, exit 0.
- [X] T002 Add helpers to `tests/smoke.sh` next to `needs_docker`: `use_fake_docker`, which makes
  `$DS_RUN/fakebin/docker` a symlink to `$REPO/tests/fake-docker`, prepends `$DS_RUN/fakebin` to
  `PATH`, sets `FAKE_DOCKER_LOG=$DS_RUN/docker.log` (emptied) and clears every `FAKE_DOCKER_*`
  variable; and `docker_calls`, which prints `$FAKE_DOCKER_LOG`.
- [X] T003 Add `tests/fake-docker` to the shellcheck file list in `tests/verify.sh` (target `lint`).

---

## Phase 2: Foundational

**Purpose**: Shared helpers that pack, unpack and sandbox all use. Blocks US1 and US2.

- [X] T004 Add `ds_docker_arch` to `lib.sh`. It maps `uname -m` to `amd64` for `x86_64`/`amd64`
  and to `arm64` for `aarch64`/`arm64`. For anything else it prints nothing and returns 1.
- [X] T005 Add `ds_sandbox_files_hash` to `lib.sh`. It prints
  `cat "$DS_ROOT/env/.config/sandbox/Dockerfile" "$DS_ROOT/env/.config/sandbox/entrypoint.sh" | cksum | cut -d' ' -f1`,
  the same value `env/.config/bin/sandbox` computes today (its `hash` before `-UID-GID`).
- [X] T006 Add `scenario_sandbox_files_hash_matches` to `tests/smoke.sh`. It checks that
  `ds_sandbox_files_hash` (from `lib.sh`) equals the files hash that installed
  `~/.config/bin/sandbox` computes. Expose that value by running `sandbox shell` with the fake
  docker and no image (`FAKE_DOCKER_IMAGE` empty), reading `--label dev-sessionizer.hash=` from
  the logged `build` call and removing its `-$(id -u)-$(id -g)` suffix. That label already exists
  today, so this works before and after T017.

**Checkpoint**: helpers in place.

---

## Phase 3: User Story 1 - Pack the sandbox image for another machine (P1) MVP

**Goal**: `./pack.sh --uid N --gid N [--arch A]` builds the image for those ids and puts it in the
archive (contracts/pack-unpack.md).

**Independent Test**: pack with `--uid 1500 --gid 1500` with the fake docker; the archive has
`dev-sessionizer/sandbox-image.tar` and the `sandbox_*` keys in `MANIFEST`; bad ids write nothing.

### Tests for User Story 1

- [X] T007 [P] [US1] Add `scenario_pack_image_args` to `tests/smoke.sh` (fake docker). Assert
  `pack.sh` exits 1 with a `dev-sessionizer:` message and leaves no file at OUTPUT for each of:
  `--uid 1500` alone; `--gid 1500` alone; `--uid 0 --gid 1500`; `--uid abc --gid 1`;
  `--uid 1 --gid 1 --arch mips`; `--arch arm64` without ids; ids given with `FAKE_DOCKER_INFO_RC=1`;
  ids given with `FAKE_DOCKER_BUILD_RC=1`; ids given with `FAKE_DOCKER_SAVE_RC=1` (stands in for a full disk); ids given with no `docker` on `PATH` (skip this case with an `ok # skip` line when a real `docker` is in `/usr/bin` or `/bin`, as `scenario_sandbox_refusals` does). Also: a file already at OUTPUT stays byte-identical after
  a failed pack. `pack.sh --help` exits 0 and prints `--uid`.
- [X] T008 [P] [US1] Add `scenario_pack_image` to `tests/smoke.sh` (fake docker). Run
  `pack.sh --uid 1500 --gid 1501 --arch arm64 OUT`. Assert: the archive lists
  `dev-sessionizer/sandbox-image.tar`; `MANIFEST` has `sandbox_uid=1500`, `sandbox_gid=1501`,
  `sandbox_arch=arm64`; the logged `build` call has `--pull`, `--no-cache`, `--platform linux/arm64`,
  `--build-arg UID=1500`, `--build-arg GID=1501`, `--build-arg OFFLINE=1`,
  `--label dev-sessionizer.packed=1`, `--label dev-sessionizer.uid=1500`,
  `--label dev-sessionizer.gid=1501`, `--label dev-sessionizer.files=<ds_sandbox_files_hash>`,
  `-t dev-sessionizer-sandbox:packed`; `save` is called with `--platform linux/arm64`, and without
  it when `FAKE_DOCKER_NO_SAVE_PLATFORM=1`; `image rm dev-sessionizer-sandbox:packed` is logged.
  A plain `pack.sh OUT` (no ids) logs no docker call at all, and its archive has no
  `sandbox-image.tar` and no `sandbox_` keys.

### Implementation for User Story 1

- [X] T009 [US1] In `pack.sh`, replace the single positional OUTPUT with a bash-3.2 `while` loop that
  takes `--uid N`, `--gid N`, `--arch A`, `-h|--help` and one positional OUTPUT in any order. Add a
  usage text matching contracts/pack-unpack.md. Validate before anything is staged: "`--uid`,
  `--gid`: both or neither; digits only; not `0`", "`--arch`: `amd64` or `arm64`; only with ids;
  default from `uname -m`" (via `ds_docker_arch`, with an error asking for `--arch` when it fails).
  With ids, check `command -v docker` and `docker info`. Every failure: `ds_err` + exit 1.
- [X] T010 [US1] In `pack.sh`, when ids are given, after staging:
  `docker build --pull --no-cache --platform "linux/$arch" --build-arg "UID=$uid" --build-arg "GID=$gid" --build-arg OFFLINE=1 --label dev-sessionizer.packed=1 --label "dev-sessionizer.uid=$uid" --label "dev-sessionizer.gid=$gid" --label "dev-sessionizer.files=$(ds_sandbox_files_hash)" -t dev-sessionizer-sandbox:packed "$DS_ROOT/env/.config/sandbox" >&2`.
  Then `docker save` (add `--platform "linux/$arch"` only when `docker save --help` mentions
  `--platform`: capture the help first with `help="$(docker save --help 2>&1 || true)"` and test it
  with `case $help in *--platform*)`, never `| grep -q`, which can fail under `pipefail`) `-o "$dest/sandbox-image.tar" dev-sessionizer-sandbox:packed`. Append
  `sandbox_uid`, `sandbox_gid` and `sandbox_arch` lines to `MANIFEST`. Log
  `ds_log "sandbox image for uid $uid gid $gid ($arch) included"`.
- [X] T011 [US1] In `pack.sh`, write the archive to `"$out.tmp.$$"` and `mv` it to `$out` only on
  success. Extend the `EXIT` trap to remove the staging folder, the temp archive and, when ids were
  given, run `docker image rm dev-sessionizer-sandbox:packed >/dev/null 2>&1 || true`.
- [X] T012 [US1] In `env/.config/sandbox/Dockerfile`, add `ARG OFFLINE=0` and
  `ENV SANDBOX_OFFLINE=$OFFLINE` (after `ARG GID`), and add `OPENCODE_DISABLE_AUTOUPDATE=1` to the
  existing `ENV` block (FR-013).

**Checkpoint**: T007/T008 pass; `pack.sh` without ids behaves exactly as before
(`scenario_pack_without_runtime_state`, `scenario_pack_unpack_roundtrip` still pass).

---

## Phase 4: User Story 2 - Use the sandbox on an airgapped machine (P1) MVP

**Goal**: Unpack loads the image. `sandbox` uses a packed image without building, refuses
mismatched ids and `--rebuild`, and OpenCode makes no blocked startup calls.

**Independent Test**: with the fake docker, unpack an archive that holds an image and check the
load/tag calls. Run `sandbox shell` against a fake packed image with matching ids: no `build` is
logged. With other ids: refused.

### Tests for User Story 2

- [X] T013 [P] [US2] Add `scenario_unpack_image` to `tests/smoke.sh` (fake docker). Build an archive
  with `pack.sh --uid "$(id -u)" --gid "$(id -g)"` (default arch), extract it with the existing
  `extract` helper, and run `unpack.sh`. Assert exit 0; `load -i …/sandbox-image.tar`,
  `tag dev-sessionizer-sandbox:packed dev-sessionizer-sandbox:latest` and
  `image rm dev-sessionizer-sandbox:packed` are logged; stdout has
  `loaded sandbox image for uid`. Then the edge cases, each still exiting 0 with the environment
  installed: `sandbox_arch` edited to the other architecture → no `load`, stderr names the
  architecture; `FAKE_DOCKER_INFO_RC=1` → no `load`, stderr has `docker load -i`; docker not on
  `PATH` → same message (same `/usr/bin`/`/bin` skip guard as `scenario_sandbox_refusals`); `FAKE_DOCKER_LOAD_RC=1` → stderr says not loaded; `sandbox_uid` edited to
  `99999` → loaded plus a warning that `sandbox` will refuse it. An archive whose runtime state is
  for another platform (`arch=bogus`) still loads the image.
- [X] T014 [P] [US2] Add `scenario_sandbox_packed_image` to `tests/smoke.sh` (fake docker, installed
  `sandbox`, a project folder under `$HOME`). With `FAKE_DOCKER_IMAGE=1 FAKE_DOCKER_PACKED=1` and
  uid/gid = `id -u`/`id -g`, `FAKE_DOCKER_FILES=<ds_sandbox_files_hash>`: `sandbox shell` succeeds,
  logs a `run` and no `build`, and prints no notice. With `FAKE_DOCKER_FILES=old`: same, plus stderr
  `image was packed from older sandbox files`. With `FAKE_DOCKER_UID=99999`: exit 1, stderr
  `image was packed for uid 99999 gid G, you are uid u gid g`, no `run` or `volume` logged. With
  `--rebuild`: exit 1, stderr `packed on another machine`, no `build` logged. Without
  `FAKE_DOCKER_PACKED` and with a matching `FAKE_DOCKER_HASH`: no `build` (local image, today's
  behaviour). With a non-matching hash: one `build` with `--label dev-sessionizer.uid=`,
  `.gid=`, `.files=`, `.hash=`.
- [X] T015 [US2] Add `scenario_agent_packed` to `tests/smoke.sh` (real Docker, `needs_docker`). Run
  `pack.sh --uid "$(id -u)" --gid "$(id -g)"`, extract it, `docker image rm dev-sessionizer-sandbox`
  (ignore failure), and run `unpack.sh`. Then `sandbox --network none shell -- -c 'id -u; id -g;
  claude --version; opencode --version; env'` in a new project. Assert: no `building` in stderr;
  the ids match; both versions print; `env` shows `SANDBOX_OFFLINE=1`,
  `OPENCODE_DISABLE_AUTOUPDATE=1`, `OPENCODE_DISABLE_MODELS_FETCH=1`,
  `OPENCODE_DISABLE_LSP_DOWNLOAD=1`. Then time
  `sandbox --network none shell -- -c 'opencode models >/dev/null 2>&1; true'` (this loads the
  providers, which is where the model list download would wait) and assert it finishes in under
  10 s (SC-002). Finally remove the image so later scenarios rebuild locally.

### Implementation for User Story 2

- [X] T016 [US2] In `unpack.sh`, between `install.sh` and the runtime-state platform check, add the
  image step from contracts/pack-unpack.md. Read `sandbox_uid`, `sandbox_gid` and `sandbox_arch` in
  the existing `MANIFEST` loop (move the loop above the step). When `$DS_ROOT/sandbox-image.tar`
  exists: compare `sandbox_arch` with `ds_docker_arch`; check `command -v docker` and `docker info`.
  Then `docker load -i`, `docker tag dev-sessionizer-sandbox:packed dev-sessionizer-sandbox:latest`
  and `docker image rm dev-sessionizer-sandbox:packed`. Every failure prints one `ds_err` with the
  reason; when Docker is missing or the daemon is down, it also gives the manual
  `docker load -i "$DS_ROOT/sandbox-image.tar"` and `docker tag …` commands. Unpack keeps going. On
  success `ds_log "loaded sandbox image for uid U gid G"`, and `ds_err` a warning when U/G ≠
  `id -u`/`id -g`. The step MUST NOT change unpack's exit status.
- [X] T017 [US2] In `env/.config/bin/sandbox`, replace the image check (the `hash`/`current`
  block) with the decision table in data-model.md. Compute `files` (cksum, unchanged) and
  `hash="$files-$(id -u)-$(id -g)"`. Read
  `{{index .Config.Labels "dev-sessionizer.packed"}}|{{index .Config.Labels "dev-sessionizer.uid"}}|{{index .Config.Labels "dev-sessionizer.gid"}}|{{index .Config.Labels "dev-sessionizer.files"}}|{{index .Config.Labels "dev-sessionizer.hash"}}`
  in one `docker image inspect` (`|| true`, so no image gives empty) and split it with
  `IFS='|' read -r packed img_uid img_gid img_files img_hash`. The separator MUST NOT be
  whitespace: a local image has empty `packed`/`uid`/`gid`, and whitespace splitting would shift
  the remaining values into the wrong variables. Packed: ids differ → `die "image was packed for uid U gid G, you are uid u gid g"`;
  `--rebuild` → `die "image was packed on another machine; repack there, or 'docker image rm dev-sessionizer-sandbox' to build locally"`;
  files differ → `printf 'sandbox: image was packed from older sandbox files; repack to update\n' >&2`;
  never build. Local: today's rebuild rule, and the build now also passes
  `--label dev-sessionizer.uid=…`, `--label dev-sessionizer.gid=…` and
  `--label dev-sessionizer.files=…`.
- [X] T018 [US2] In `env/.config/sandbox/entrypoint.sh`, before the `case "$mode"`, add: when
  `${SANDBOX_OFFLINE:-0}` is `1`, `export OPENCODE_DISABLE_MODELS_FETCH=1 OPENCODE_DISABLE_LSP_DOWNLOAD=1`
  (FR-014; no models snapshot, the target's OpenCode config supplies the models).

**Checkpoint**: MVP. Quickstart steps 1–4 pass.

---

## Phase 5: User Story 3 - Choose the default agent in sandbox.env (P2)

**Goal**: `SANDBOX_AGENT=claude|opencode` in `~/.config/local/sandbox.env` sets the default mode.

**Independent Test**: with the fake docker and a local image, `sandbox` logs a `run` ending in
`opencode` when the file says so, `claude` when the setting is absent, and refuses `vim`.

### Tests for User Story 3

- [X] T019 [P] [US3] Add `scenario_sandbox_default_agent` to `tests/smoke.sh` (fake docker,
  `FAKE_DOCKER_IMAGE=1` with a matching `FAKE_DOCKER_HASH`). Check the mode word in the logged
  `run` call for each case: no file → `claude`; file without the key → `claude`;
  `SANDBOX_AGENT=opencode` → `opencode`; `SANDBOX_AGENT=claude` then a later
  `SANDBOX_AGENT=opencode` → `opencode` (last wins); `# SANDBOX_AGENT=opencode` only → `claude`;
  `SANDBOX_AGENT=opencode` with `sandbox claude` → `claude`; with `sandbox shell` → `shell`.
  `SANDBOX_AGENT=vim` and `SANDBOX_AGENT="opencode"`: exit 1, stderr has
  `SANDBOX_AGENT=vim in` and `is not supported (claude, opencode)`, nothing logged at all (checked
  before any Docker call). `SANDBOX_AGENT=vim` with `sandbox claude` → succeeds.
- [X] T020 [P] [US3] Extend `scenario_sandbox_install` in `tests/smoke.sh`: a fresh `sandbox.env`
  contains `# SANDBOX_AGENT=opencode`, and the existing check that install keeps the file is
  unchanged.

### Implementation for User Story 3

- [X] T021 [US3] In `env/.config/bin/sandbox`, after argument parsing and before
  `mode="${mode:-claude}"`, when `mode` is empty and `$env_file` exists, read it with
  `while IFS= read -r line || [[ -n $line ]]`. Skip empty lines and lines starting with `#`. For a
  line starting with `SANDBOX_AGENT=`, keep `${line#SANDBOX_AGENT=}` verbatim (last wins). If a
  value was found and it is not `claude` or `opencode`,
  `die "SANDBOX_AGENT=$value in ~/.config/local/sandbox.env is not supported (claude, opencode)"`.
  Otherwise use it as the mode. This must stay before the folder and Docker checks.
- [X] T022 [US3] In `env/.config/bin/sandbox` `usage()`, add a line:
  `Default agent: SANDBOX_AGENT=claude|opencode in ~/.config/local/sandbox.env (else claude).`
- [X] T023 [P] [US3] In `install.sh`, add to the `sandbox.env` heredoc (new files only):
  `# Agent started by \`sandbox\` when none is named: claude (default) or opencode.` and
  `# SANDBOX_AGENT=opencode`.

**Checkpoint**: quickstart step 5 passes.

---

## Phase 6: User Story 4 - No bypass-permissions warning in Claude Code (P3)

**Goal**: Claude Code in the sandbox starts without the bypass-permissions dialog; host config
unchanged.

**Independent Test**: in a real sandbox with a host `settings.json` lacking the key, the
container's copy has `"skipDangerousModePermissionPrompt": true` and the host file is
byte-identical afterwards.

### Tests for User Story 4

- [X] T024 [US4] Extend `scenario_agent_config` in `tests/smoke.sh` (real Docker). With a host
  `~/.claude/settings.json` of `{"theme":"dark"}`, check that
  `sandbox shell -- -c 'jq -r .skipDangerousModePermissionPrompt ~/.claude/settings.json; jq -r .theme ~/.claude/settings.json'`
  prints `true` and `dark`. (The interactive dialog cannot be checked from a script; the key in the container copy is the check for "no dialog", since Claude Code skips the dialog exactly when it is set.) With no host `settings.json`, it prints `true`. With an invalid host
  `settings.json` (`{`), the shell still starts and stderr has a one-line warning. In every case the
  host file is byte-identical afterwards (cksum before/after).

### Implementation for User Story 4

- [X] T025 [US4] In `env/.config/sandbox/entrypoint.sh`, after the `copy_tree`/`copy_file` calls,
  set the key in `$HOME/.claude/settings.json`. Create it as `{}` when missing (with `mkdir -p`),
  then
  `jq '.skipDangerousModePermissionPrompt = true' settings.json > settings.json.tmp && mv settings.json.tmp settings.json`.
  If `jq` fails (invalid JSON), remove the temp file, print
  `sandbox: ~/.claude/settings.json is not valid JSON; Claude Code will ask to confirm bypass mode`
  to stderr, and continue (research R9).

**Checkpoint**: quickstart step 6 passes.

---

## Phase 7: Polish & Cross-Cutting Concerns

- [X] T026 [P] Update `README.md`:
  - "Transporting to an airgapped machine": `./pack.sh --uid N --gid N [--arch amd64|arm64]`; get the
    ids with `id -u`/`id -g` on the target; the archive grows by the image; cross-architecture builds
    need Docker Desktop or `binfmt`/QEMU on Linux; what unpack prints when it cannot load.
  - "Agent sandbox": `SANDBOX_AGENT` in `sandbox.env`; packed images are never rebuilt, refuse other
    ids and `--rebuild`, and how to go back to local builds; the first start after updating rebuilds the local image once, because the image files changed; the bypass-permissions dialog is skipped
    inside the sandbox only.
  - Replace "The sandbox needs network, so it does not work on an airgapped machine" with the table
    from spec.md Context: what still needs network on the target and what is turned off.
- [X] T027 [P] Add **Packed image** to `CONTEXT.md`: "The agent sandbox image built by pack for a
  target user's ids and carried inside the pack archive; loaded by unpack. _Avoid_: exported image,
  offline image."
- [X] T028 [P] Update `specs/003-agent-sandbox/spec.md` Assumptions: the line saying the sandbox is
  not carried by pack now points to feature 004.
- [X] T029 Run `tests/verify.sh lint mac linux` and fix every failure.
- [ ] T030 Run `tests/verify.sh sandbox` on the Linux host and fix every failure.
- [ ] T031 By hand on macOS (Docker Desktop): quickstart step 1 with `--arch amd64`, then load that
  archive on a Linux machine and run quickstart steps 2–4 with `--network none` (constitution
  workflow: macOS + Linux).

---

## Dependencies & Execution Order

- **Setup (T001–T003)** → **Foundational (T004–T006)** → stories.
- **US1 (T007–T012)**: needs Foundational. T012 (Dockerfile) is independent of T009–T011.
- **US2 (T013–T018)**: T013 and T015 need US1's pack. T014, T017 and T018 need only Foundational.
- **US3 (T019–T023)**: needs only Setup. Independent of US1/US2, but T021 and T017 edit the same
  file (`env/.config/bin/sandbox`), so do them one after the other.
- **US4 (T024–T025)**: independent. T025 and T018 edit `entrypoint.sh`, so do them one after the
  other.
- **Polish**: after the stories it documents. T029–T031 last.

```text
T001-T003 ─▶ T004-T006 ─┬─▶ US1 (T007-T012) ─▶ US2 (T013, T015, T016)
                        ├─▶ US2 (T014, T017, T018)
                        ├─▶ US3 (T019-T023)
                        └─▶ US4 (T024-T025)
                                         all ─▶ T026-T031
```

## Parallel Examples

- After Phase 2: T007, T008, T012, T014, T019, T020 and T023 (different files or independent
  scenario functions; scenarios in `tests/smoke.sh` are separate functions, but merge them one at a
  time).
- US1 + US4 side by side: one person on `pack.sh` (T009–T011), another on `entrypoint.sh` (T025).
- Polish: T026, T027 and T028 together.

## Implementation Strategy

1. **MVP = US1 + US2**: Setup, Foundational, T007–T018. Then validate quickstart 1–4 on a real
   offline target. This alone meets the main request.
2. **US3**: default agent. Small, can ship in the same change.
3. **US4**: Claude dialog. Small, independent.
4. **Polish**: README, CONTEXT, full verify on both platforms.
