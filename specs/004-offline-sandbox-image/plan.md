# Implementation Plan: Offline Sandbox Image and Default Agent

**Branch**: `004-offline-sandbox-image` | **Date**: 2026-11-03 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/004-offline-sandbox-image/spec.md`

## Summary

`./pack.sh --uid N --gid N [--arch amd64|arm64]` builds the sandbox image for the target user with
`docker build --pull --no-cache --platform linux/ARCH`. It saves the image with `docker save` into
the archive as `dev-sessionizer/sandbox-image.tar` and records ids and architecture in `MANIFEST`.
`unpack.sh` loads the image after install and before the runtime-state platform check, tags it as
the normal sandbox image, and reports when it cannot.

The image carries its identity as labels (`dev-sessionizer.packed`, `.uid`, `.gid`, `.files`).
`sandbox` never rebuilds a packed image. It refuses one built for other ids, prints a notice when
the image files are newer than the image, and refuses `--rebuild`. A packed image is built with
`OFFLINE=1`. The entrypoint then turns off OpenCode's model catalog download and language server
downloads; the models come from the target's own OpenCode config. OpenCode's update
check is turned off in every image.

`sandbox` reads `SANDBOX_AGENT=claude|opencode` from `~/.config/local/sandbox.env` as the default
agent. The entrypoint adds `"skipDangerousModePermissionPrompt": true` to the container's copy of
`~/.claude/settings.json`, so Claude Code does not show the bypass-permissions dialog.

The research behind each choice is in [research.md](research.md).

## Technical Context

**Language/Version**: bash (3.2-compatible for `pack.sh`, `unpack.sh`, `lib.sh` and `sandbox`);
bash in the Debian image for the entrypoint; the existing Dockerfile.

**Primary Dependencies**: Docker with BuildKit (`docker build --platform`, `docker save`,
`docker load`), needed only when packing with ids, unpacking an archive with an image, or running
`sandbox`. `jq` is already in the image.

**Storage**: `sandbox-image.tar` inside the pack archive; image labels; new `MANIFEST` keys; one new
line in the `sandbox.env` template.

**Testing**: `tests/smoke.sh` with a fake `docker` on `PATH`, so pack validation, unpack loading,
packed-image checks and the default agent setting run without Docker or network (SC-004).
`tests/verify.sh sandbox` gets one real-Docker scenario that packs for other ids, loads the image,
and runs a session with `--network none`. `tests/verify.sh lint` as before.

**Target Platform**: pack on macOS (Docker Desktop) or Linux (Docker Engine). The target is Linux
with Docker Engine, no outbound network.

**Project Type**: CLI scripts in a dotfiles/toolkit repo.

**Performance Goals**: OpenCode starts in under 10 s on the target with no mise tools (SC-002). The
`sandbox` start time for a packed image is the same as for a local one (one extra label lookup in
the existing `docker image inspect`).

**Constraints**: `sandbox`, `unpack.sh` make no network request (SC-001); pack and unpack without
an image still need no Docker (FR-004, FR-022); the host Claude Code config stays unchanged
(FR-020).

**Scale/Scope**: about 60 lines in `pack.sh`, 30 in `unpack.sh`, 30 in `sandbox`, 15 in the
entrypoint, 5 in the Dockerfile; one line in the install template; smoke scenarios with a fake
`docker`; README updates.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Portable across macOS and Linux | PASS | New host code uses `case` and `[[ =~ ]]` for validation, `cksum` for the files hash and `uname -m` mapped to Docker architectures. Docker is checked with `command -v` only when ids are given or the archive has an image; pack without ids, install and unpack without an image never touch it. |
| II. One-command install and update | PASS | Install changes only the create-once `sandbox.env` template. Unpack stays one command and loads the image as part of it. |
| III. Transferable via files | PASS, and it closes 003's deviation | The sandbox image now travels in the pack archive, and unpack restores it with no network. The remaining network needs at runtime (model server, mise tools, packages) belong to the projects and the developer's own setup, not to the toolkit. They are documented (FR-015). |
| IV. Overwriteable by design | PASS | `SANDBOX_AGENT` lives in the user-owned `sandbox.env`; an existing file is never rewritten. The Claude Code setting is written only to the container's copy. |
| V. Minimal and simple | PASS | No new files except a test helper. Image identity uses Docker labels instead of a side file. Pack builds with plain `docker build`; no separate build tool or registry. |
| Workflow: macOS + Linux before merge | PLANNED | Fake-docker scenarios run in `mac` and `linux`. The real-Docker pack/load scenario runs in `tests/verify.sh sandbox` on the author's Linux host; packing from macOS for a Linux amd64 target is checked by hand (quickstart step 1). |
| Workflow: README in same change | PLANNED | Pack section: `--uid`, `--gid`, `--arch`. Sandbox section: `SANDBOX_AGENT`, packed images, the "still needs network" table. Remove "does not work on an airgapped machine". |
| Vocabulary (`CONTEXT.md`) | PLANNED | Uses Pack, Unpack, Airgapped environment, Agent sandbox as defined. Add **Packed image** (the sandbox image carried in a pack archive). |

Post-design re-check: still PASS on all five principles. No entries in Complexity Tracking.

## Project Structure

### Documentation (this feature)

```text
specs/004-offline-sandbox-image/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   ├── pack-unpack.md
│   └── sandbox.md
├── checklists/requirements.md
└── tasks.md             # /speckit-tasks
```

### Source Code (repository root)

```text
pack.sh                          # --uid/--gid/--arch, image build + save, MANIFEST keys
unpack.sh                        # load image before the runtime-state platform check
lib.sh                           # ds_docker_arch (uname -m -> amd64/arm64), ds_sandbox_files_hash
install.sh                       # sandbox.env template: commented SANDBOX_AGENT line
env/.config/bin/sandbox          # SANDBOX_AGENT default; packed-image checks; split labels
env/.config/sandbox/Dockerfile   # ARG OFFLINE, labels set by caller, OPENCODE_DISABLE_AUTOUPDATE
env/.config/sandbox/entrypoint.sh# offline OpenCode flags; skipDangerousModePermissionPrompt in settings copy
tests/smoke.sh                   # fake-docker scenarios + one real-Docker pack/load scenario
tests/fake-docker                # records calls, answers inspect/info/load/save from env vars
README.md, CONTEXT.md
```

**Structure Decision**: Existing layout; no new top-level folders. `sandbox` does not source
`lib.sh` (it is installed to `~/.config/bin` without it), so the files hash is a one-line
`cksum` written in both `sandbox` and `lib.sh`. A smoke scenario checks that both give the same value.

## Complexity Tracking

None.
