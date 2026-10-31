# Implementation Plan: Agent Sandbox

**Branch**: `003-agent-sandbox` | **Date**: 2026-10-31 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/003-agent-sandbox/spec.md`

## Summary

A new `sandbox` command runs Claude Code (or OpenCode, or a shell) in a throwaway Docker container
with permission prompts off. The container runs as a user built with the host's UID/GID and has no
capabilities, `no-new-privileges` and no sudo. The project is mounted read-write at its host path.
Host agent config is mounted read-only and copied into the container's home at start. A per-project
volume caches mise tools and package downloads. The network defaults to the bridge network and can
be overridden. The image files (`Dockerfile`, `entrypoint.sh`) ship under `env/.config/sandbox`. The
image is rebuilt automatically when they change. Experiments behind each choice are in
[research.md](research.md).

## Technical Context

**Language/Version**: bash for the command, which stays bash 3.2-compatible like the other
scripts. The entrypoint is bash in the image (Debian). The image is defined in a Dockerfile.

**Primary Dependencies**: Docker (optional tool, like `flux`). Installed into the image at build
time: Claude Code, OpenCode and mise via their official installers, and Debian packages.

**Storage**: Docker image `dev-sessionizer-sandbox`; one named volume per project; user-owned
`~/.config/local/sandbox.env`.

**Testing**: `tests/smoke.sh`. Install and refusal scenarios need no Docker. Docker scenarios
(`scenario_agent_*`) run only via the new `tests/verify.sh sandbox` target, which needs Docker and
network. Plus `tests/verify.sh lint`.

**Target Platform**: macOS (Docker Desktop) and Linux (Docker Engine, rootful).

**Project Type**: CLI script in a dotfiles/toolkit repo.

**Performance Goals**: start under 5 s with the image built and no tools to install (SC-001); a
second start of a project downloads nothing (SC-005).

**Constraints**: no root in the container at any point after build; no host writes outside the
project; install must not need Docker or network.

**Scale/Scope**: about 150 lines for `sandbox`, 40 for the entrypoint and 40 for the Dockerfile;
small changes to `install.sh`, `lib.sh` and the tests; a README section; a `CONTEXT.md` term.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Portable across macOS and Linux | PASS | Host-side code uses `cksum`, `pwd -P` and bash 3.2 constructs; no `readlink -f` or `sha256sum`. Docker is detected with `command -v` and its absence fails only the `sandbox` command, never install. Platform differences (Keychain login on macOS) are handled by one token mechanism on both. |
| II. One-command install and update | PASS | `install.sh` gains one `replace` for `~/.config/sandbox` and one create-once override. Both are idempotent. `ds_managed` lists the new path. |
| III. Transferable via files | DEVIATION, justified | Building the image downloads the agents, mise and Debian packages. See Complexity Tracking. Install, pack and unpack stay offline; the files are packed like the rest of `env/`. |
| IV. Overwriteable by design | PASS | `~/.config/sandbox` is replaced on every install. Machine-local settings live in `~/.config/local/sandbox.env` (created once, never rewritten) and `SANDBOX_NETWORK` in `~/.bashrc`. |
| V. Minimal and simple | PASS | Three files and plain bash; no new language or framework. Hardening is a handful of `docker run` flags. Network allowlisting and `.git` guards were left out on purpose (research R10, R11). |
| Workflow: macOS + Linux before merge | PLANNED | `tests/verify.sh sandbox` on Docker Desktop (author's Mac) and on the author's Linux host (with `SANDBOX_NETWORK=host`). Smoke scenarios run on both via `mac` and `linux`. |
| Workflow: README in same change | PLANNED | New "Agent sandbox" section, Docker listed under optional prerequisites, `sandbox.env` added to the overrides table. |
| Vocabulary (`CONTEXT.md`) | PLANNED | Add **Agent sandbox**, distinct from the tests' sandbox `HOME`. |

**Post-design re-check**: unchanged. The only deviation is III, which is justified below.

## Project Structure

### Documentation (this feature)

```text
specs/003-agent-sandbox/
├── spec.md
├── plan.md              # this file
├── research.md          # R1–R12: layout, image, user, mounts, config, logins, agents, cache,
│                        # hardening, network, git, testing
├── data-model.md        # image, cache volume, session mounts, env file, path validation
├── quickstart.md        # automated and manual validation
├── contracts/cli.md     # sandbox command, exit codes, environment, install changes
├── checklists/requirements.md
└── tasks.md             # /speckit-tasks (not yet created)
```

### Source Code (repository root)

```text
env/.config/bin/sandbox            # new: parse args, validate DIR, build/check image, docker run
env/.config/sandbox/Dockerfile     # new: debian:stable-slim, agent user (UID/GID args), tools,
                                   # Claude Code, OpenCode, mise; no sudo
env/.config/sandbox/entrypoint.sh  # new: copy /host config into $HOME, mise install, exec mode
install.sh                         # replace ~/.config/sandbox; create ~/.config/local/sandbox.env
lib.sh                             # ds_managed: add ~/.config/sandbox
tests/smoke.sh                     # sandbox install/refusal scenarios; Docker-gated scenario_agent_*
                                   # (isolation, ownership, config, cache, push)
tests/verify.sh                    # new `sandbox` target; lint the entrypoint
README.md                          # Agent sandbox section, prerequisites, overrides table
CONTEXT.md                         # Agent sandbox term
```

**Structure Decision**: Follow the existing layout. Deployable files go under `env/`, mirroring
`$HOME`. Tests go in `tests/`, behind a `verify.sh` target.

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| III: the sandbox image downloads third-party code (agents, mise, Debian packages) when it is first built, instead of vendoring it | The sandbox exists to run network-dependent agents: they need the model API and package registries for the whole session. In an airgapped environment the feature has no use at all. | Vendoring the Claude Code and OpenCode binaries and the Debian packages would add hundreds of MB to the repo and the pack archive, for every platform and architecture. They would go stale within days, for a feature that cannot run offline anyway. Like `flux` and `talosctl`, the sandbox is optional and skipped where its tool is missing. |
