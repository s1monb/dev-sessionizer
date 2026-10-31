# Research: Agent Sandbox

Experiments were run on the author's machine (macOS 27, arm64, Docker Desktop with engine 29.9)
on 2026-10-31 with `debian:stable-slim`.

## R1. Where the sandbox files live

**Decision**: Three files.

- `env/.config/bin/sandbox`: the command. It is installed with the rest of `~/.config/bin`.
- `env/.config/sandbox/Dockerfile` and `env/.config/sandbox/entrypoint.sh`: the image. Install
  copies them to `~/.config/sandbox`, which becomes a managed path (`ds_managed`).

The command finds the image files at `<its own folder>/../sandbox`, so it works both from
`~/.config/bin` and from `env/.config/bin` in the repo.

**Rationale**: Keeping the entrypoint in its own file means `tests/verify.sh lint` checks it with
shellcheck like every other script. Install changes by one `replace` line.

**Alternatives considered**: Generating the Dockerfile from a heredoc inside the script, as
megaclaude does. That gives one file, but neither the Dockerfile nor the entrypoint gets linted, and
the script becomes harder to read.

## R2. Building the image and noticing changes

**Decision**: The image is tagged `dev-sessionizer-sandbox` and carries a label
`dev-sessionizer.hash`. The label holds a `cksum` of the Dockerfile, the entrypoint, the host UID and
the host GID. Before each run the command compares the label with the current value and builds when
they differ or the image is missing. `--rebuild` builds with `--pull --no-cache`, which also picks up
new agent versions.

**Rationale**: `cksum` is POSIX and behaves the same on macOS and Linux, while `shasum` and
`sha256sum` differ between them. Checking the label costs one `docker image inspect`, about 50 ms.
Running `docker build` on every start would also hit the cache, but adds about a second and prints
build output.

**Alternatives considered**: Putting the hash in the tag. Every change would leave another tagged
image behind. With one tag, an old image just becomes dangling and `docker image prune` removes it.

## R3. Matching the host user

**Decision**: The image is built with `--build-arg UID=$(id -u) --build-arg GID=$(id -g)`. The
Dockerfile reuses an existing group with that GID or creates one, then creates user `agent` with
that UID and home `/home/agent`. Build fails with a clear message when the UID is already taken in
the base image. The command refuses to run when the host UID is 0.

**Rationale**: Creating the user at build time means nothing runs as root at runtime, and tools
such as mise and npm get a real passwd entry and home. That is not the case with a bare
`--user uid:gid`.

**Evidence**: The base image has no regular users, so common UIDs (501 on macOS, 1000 on Linux) are
free. GID 20 (macOS `staff`) already exists in Debian as `dialout`, so the group has to be reused,
not created. A file created in the container appeared on the macOS host as `501` (the host user).

**Alternatives considered**: A root entrypoint that runs `useradd` at start (megaclaude). That needs
root and setuid capabilities in every session, which conflicts with FR-008.

## R4. Where the project is mounted

**Decision**: The project is bind-mounted read-write at **the same absolute path as on the host**,
and that is the working folder. The command refuses `/`, `$HOME`, and any folder that contains
`$HOME`.

**Rationale**: Claude Code keys per-project state in `~/.claude.json`, such as folder trust and
allowed tools, by absolute path, so host entries apply unchanged. Paths in errors and logs also
match the host. It costs the same as mounting at `/workspace`.

**Alternatives considered**: `/workspace`, as in the original article. It works too, but host
per-project entries do not apply, and Claude Code asks to trust `/workspace` in every fresh
session.

## R5. Inheriting host config read-only

**Decision**: When they exist, these are mounted read-only:

| Host | Container (read-only) |
|------|-----------------------|
| `~/.claude` | `/host/claude` |
| `~/.claude.json` | `/host/claude.json` |
| `~/.config/opencode` | `/host/opencode-config` |
| `~/.local/share/opencode/auth.json` | `/host/opencode-auth.json` |

At start the entrypoint copies them into `/home/agent`, where the agent may change them for that
session only. Session history and caches are left out, so start-up stays fast and the agent does
not see transcripts from other projects:

- From `~/.claude`: `projects`, `file-history`, `history.jsonl`, `sessions`, `session-env`,
  `shell-snapshots`, `paste-cache`, `cache`, `backups`, `todos`, `statsig`, `debug`, `ide`, and
  `.credentials.json` (see R6).
- From `~/.config/opencode`: `node_modules`. It can hold macOS-native modules, and OpenCode
  reinstalls plugins from `package.json`.

**Rationale**: A writable `~/.claude` would let the agent add hooks or MCP servers that run on the
host the next time Claude Code runs there unsandboxed. Copying gives a normal writable config
inside without that risk.

**Evidence**: Writing to a `:ro` bind mount fails with "Read-only file system" for an agent with no
capabilities.

**Known limitation**: A config file that is a symlink to a location outside the mounted folder
(for example a dotfiles repo) arrives dangling. This is documented, not solved.

## R6. Logins

**Decision**:

- **Claude Code**: pass `CLAUDE_CODE_OAUTH_TOKEN` and `ANTHROPIC_API_KEY` from the host environment
  when set. Also read an optional, user-owned `~/.config/local/sandbox.env` (`KEY=value` lines,
  passed with `--env-file`, never sourced), which install creates once with mode 600. The README
  recommends putting a token from `claude setup-token` there.
- **OpenCode**: copy `auth.json` into the session.
- **Not copied**: Claude Code's own `.credentials.json` (Linux).

**Rationale**: On macOS the Claude Code login is in the Keychain, so a token is the only option
there. On Linux, copying `.credentials.json` would work at first, but OAuth refresh tokens rotate.
A refresh inside the sandbox would invalidate the host's copy and log the host out. A
`setup-token` token is long-lived and meant for this. The env file keeps the token out of every
shell's environment and is an override in the sense of constitution IV. OpenCode OAuth providers
have the same rotation risk, which is documented. API-key providers are unaffected.

**Alternatives considered**: A persistent login volume shared by all sandboxes. It is writable
shared state again, and it adds a login step per machine for no gain over a token.

## R7. Agents and permission prompts

**Decision**:

- Claude Code is installed with its native installer, and OpenCode and mise with theirs. All three
  run as `agent` at build time and install into `~/.local/bin` or `~/.opencode/bin`.
  `DISABLE_AUTOUPDATER=1` is set, because updates would be lost with the container.
- Claude Code runs as `claude --dangerously-skip-permissions`. OpenCode runs as `opencode --auto`,
  which per its [permissions docs](https://opencode.ai/docs/permissions/) approves every request not
  explicitly denied. Explicit `deny` rules in the developer's OpenCode config still apply.
- Base image: `debian:stable-slim` with `git ca-certificates curl ripgrep jq less procps unzip
  xz-utils zip build-essential` and `LANG=C.UTF-8`. **No sudo.**

**Rationale**: The agent cannot install system packages without root, so the image carries the
common tools agents use: search, archives, a C toolchain for native builds. Everything else comes
from mise. Installing as `agent` keeps the binaries in the user's home, as the installers expect.

**Verified during implementation (2026-10-31)**:

- OpenCode 1.19.5 lists `--auto  auto-approve permissions that are not explicitly denied`.
- The image builds Claude Code 2.1.314 and mise 2026.10.23.
- Running `claude --version` at build time leaves `~/.claude` and `~/.claude.json` in the image, so
  the Dockerfile removes them. Each session then starts from the host copy only.
- Still open: whether Claude Code shows a bypass-permissions confirmation on first start with a
  copied `~/.claude.json`. This needs a real login (tasks T015).

## R8. Tool cache

**Decision**: One named volume per project, `dev-sessionizer-sandbox-<folder name>-<cksum of
path>`, mounted at `/cache`. The image creates `/cache` owned by `agent`, so a new volume takes that
owner. The environment points tools there:

| Variable | Value |
|----------|-------|
| `MISE_DATA_DIR` | `/cache/mise` |
| `XDG_CACHE_HOME` | `/cache/xdg` (pip, go build cache, mise downloads) |
| `npm_config_cache` | `/cache/npm` |
| `GOPATH` | `/cache/go` |
| `CARGO_HOME` | `/cache/cargo` |

`PATH` is prefixed with `/cache/mise/shims`. The entrypoint runs `mise install` when the project has
`mise.toml`, `.mise.toml` or `.tool-versions`, with `MISE_TRUSTED_CONFIG_PATHS` set to the project.
A failure prints a warning and the agent starts anyway (FR-015). `--reset` removes the volume.

**Rationale**: A volume per project keeps one project's agent from replacing a binary that another
project's sandbox runs (spec assumptions). Docker copies an image folder's ownership into a new
empty volume mounted over it, so no root step is needed. Setting `MISE_TRUSTED_CONFIG_PATHS` avoids
writing trust state.

## R9. Container hardening

**Decision**: `docker run --rm -i [-t] --init --cap-drop=ALL --security-opt=no-new-privileges
--pids-limit=4096 --hostname sandbox`, with the image's `USER agent`. There is no `--privileged`,
no `-p`, no Docker socket and no SSH agent. Only an explicit list of environment variables is
passed (contracts/cli.md). `-t` is added only when stdin and stdout are terminals, so tests can run
the sandbox non-interactively.

**Evidence**: Inside such a container `/proc/self/status` shows `CapEff: 0000000000000000` and
`NoNewPrivs: 1`.

**Rationale**: `--init` reaps zombie processes from the agent's many child processes. The pids
limit stops a runaway fork loop. That matters on Linux, where the container shares the host kernel.
A read-only root filesystem was considered and dropped: the container is thrown away anyway, and
the agent needs a writable home.

## R10. Network

**Decision**: `--network` comes from the `--network MODE` option, then `$SANDBOX_NETWORK`, then
`bridge`. The value goes to `docker run --network` as given.

**Rationale**: This covers the author's Linux machine, where the bridge has no internet
(`SANDBOX_NETWORK=host` in `~/.bashrc`). The planned allowlist fits the same option: an internal
network named here, plus proxy variables in `sandbox.env`.

## R11. Git inside the sandbox

**Decision**: The project's `.git` stays writable, so the agent can commit. Git identity comes from
the host's `git config user.name` and `user.email`, passed as `GIT_AUTHOR_*` and `GIT_COMMITTER_*`.
`GIT_TERMINAL_PROMPT=0` makes a push without credentials fail at once. The image sets
`safe.directory=*` so ownership differences on Docker Desktop mounts never block git.

**Evidence and accepted risk**: Read-only mounts over `.git/hooks` and `.git/config` work, and a
separate `.git` mount stops the agent from renaming `.git` (`Device or resource busy`). But the
agent can still write `.git/commondir`, and host git honours it: hooks, config and refs then come
from any folder the agent picks. Full protection would mean a read-only `.git`, with no commits
inside. The author chose a writable `.git` and a README warning (spec FR-006a).

**Also documented**: a remote URL with an embedded token lets the agent push, and git worktrees
(whose `.git` points outside the project) do not work inside.

## R12. Testing

**Decision**: All scenarios live in `tests/smoke.sh`, to reuse its throwaway `HOME`, assert helpers
and runner:

- **No Docker needed**, so these run in every `mac` and `linux` run:
  - `scenario_sandbox_install`: install deploys `sandbox` and `~/.config/sandbox`, and creates
    `sandbox.env` with mode 600 without overwriting it later;
  - `scenario_sandbox_refusals`: refusals of `$HOME`, `/` and unknown arguments happen before any
    Docker call, and "docker not found" is reported with `PATH=/usr/bin:/bin`.
- **Docker needed**, named `scenario_agent_*`: these print a skip line and return unless
  `DS_DOCKER_TESTS=1`. A new `tests/verify.sh sandbox` target sets the flag and runs only those
  scenarios. It needs Docker and network, and is not part of `all`. The scenarios set
  `DOCKER_CONFIG` to the real `~/.docker` so the Docker CLI keeps its context and plugins despite
  the fake `HOME`. They run `sandbox shell DIR -- -c '…'` to check:
  - SC-002: no writes outside the project, no capabilities, `NoNewPrivs: 1`, no `sudo`, no Docker
    socket, no `SSH_AUTH_SOCK`;
  - SC-003: host ownership of created files;
  - SC-004: host config byte-identical after the agent edits its copy;
  - SC-005: a tool installed in one session works in the next with `--network none`, and `--reset`
    empties the cache;
  - a push that fails;
  - `claude --version` and `opencode --version`.
- **Lint**: add `env/.config/sandbox/entrypoint.sh` to `shipped_scripts`.

**Rationale**: The Linux smoke test runs inside a container and cannot start containers (no
Docker-in-Docker). The Docker scenarios use the host engine instead: Docker Desktop on macOS, Docker
Engine on Linux. Running `verify.sh sandbox` on both covers the constitution's two-platform rule.
A separate test script would duplicate the harness.

**Alternatives considered**: A separate `tests/sandbox.sh`, which was the first draft of this plan.
