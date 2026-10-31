# Feature Specification: Agent Sandbox

**Feature Branch**: `003-agent-sandbox`

**Created**: 2026-10-31

**Status**: Draft

**Input**: User description: "Set up a way to sandbox Claude in a container: mount the project directory,
install the agent and mise inside, run it without permission prompts, keep git credentials, SSH keys
and the host filesystem outside. Support OpenCode as well as Claude Code. Agent config is inherited from
the host. The container must not be privileged. Files the agent creates are owned by the host user."

## Context

Running a coding agent with its permission prompts turned off is much faster, but on the host it can
delete files outside the project, read credentials, or push to remote repos. The idea is to run the
agent in a throwaway container that can only write to one project folder and holds no credentials
except the one it needs to talk to its model. The agent keeps full internet access in this feature:
it needs it for its model and for documentation and packages. Limiting outbound traffic to an
allowlist is planned as a later feature.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Run an agent on a project without prompts, safely (Priority: P1)

A developer is in a project folder and runs `sandbox`. Claude Code starts inside a container, with
permission prompts turned off and the project as its working folder. The agent can edit, build, test
and install packages freely. When the developer quits, the container is gone; the changes to the
project remain on the host, owned by the developer.

**Why this priority**: This is the feature. Everything else adds to it.

**Independent Test**: In a scratch git repo, run `sandbox`, ask the agent to create a file, commit
it, try to write outside the project, and try to push. On the host, check the file exists and is
owned by the developer, the commit is there, nothing outside the project changed, and the push
failed.

**Acceptance Scenarios**:

1. **Given** a project folder, **When** the developer runs `sandbox` in it, **Then** Claude Code
   starts in that folder inside a container with permission prompts turned off.
2. **Given** a running sandbox, **When** the agent creates or edits files in the project, **Then**
   the changes appear on the host and are owned by the developer's user and group.
3. **Given** a running sandbox, **When** the agent tries to write anywhere outside the project,
   **Then** nothing on the host outside the project changes.
4. **Given** a project with a remote, **When** the agent commits and pushes, **Then** the commit
   succeeds locally and the push fails for lack of credentials.
5. **Given** the developer quits the agent, **When** they list containers, **Then** the sandbox
   container no longer exists.

---

### User Story 2 - The agent uses the developer's own config (Priority: P1)

Inside the sandbox the agent behaves like it does on the host: the same settings, global
instructions, custom agents, commands and MCP servers, and the developer is already logged in. The
agent cannot change the host copy of that config.

**Why this priority**: Without it the sandbox feels like a different tool, and the developer has to
log in and set up config again. Read-only matters as much as inherited: a writable config folder
would let the agent add hooks that later run on the host outside the sandbox.

**Independent Test**: Put a marker instruction in the host's global agent instructions. Start the
sandbox and check the agent sees it. Ask the agent to change its settings file, quit, and check the
host settings file is unchanged.

**Acceptance Scenarios**:

1. **Given** host config for the agent, **When** the sandbox starts, **Then** the agent uses that
   config.
2. **Given** a login token for the agent in the developer's environment, **When** the sandbox
   starts, **Then** the agent is logged in without any login step.
3. **Given** a running sandbox, **When** the agent changes its own config, **Then** the change
   lasts only for that session and the host config is unchanged.
4. **Given** a host with none of the agent's config, **When** the sandbox starts, **Then** it starts
   normally and the agent asks the developer to log in.

---

### User Story 3 - Choose OpenCode instead of Claude Code (Priority: P2)

The developer runs `sandbox opencode` and gets OpenCode, with the same isolation and with its own
host config and login inherited the same way.

**Why this priority**: Requested, but Claude Code is the default and covers most use.

**Independent Test**: Run `sandbox opencode` in a scratch repo, check OpenCode starts with the host
provider login, and repeat the isolation checks from User Story 1.

**Acceptance Scenarios**:

1. **Given** host OpenCode config and login, **When** the developer runs `sandbox opencode`,
   **Then** OpenCode starts in the project with that config and login and without permission
   prompts.
2. **Given** an agent name the command does not know, **When** the developer runs it, **Then** it
   exits with a message listing the supported agents and starts nothing.

---

### User Story 4 - Project toolchains are ready and fast to restart (Priority: P2)

If the project declares its tool versions for mise, they are installed when the sandbox starts.
Tools and package downloads are kept between sessions, so the second start of the same project does
not download them again. The developer can wipe that cache or rebuild the sandbox image when needed.

**Why this priority**: Without toolchains the agent cannot build or test; without the cache each
start pays the download again.

**Independent Test**: In a project that pins a tool version, start the sandbox and check the tool is
available at that version. Quit and start again; check nothing is downloaded the second time. Run the
reset option and check the next start downloads again.

**Acceptance Scenarios**:

1. **Given** a project with a mise tool versions file, **When** the sandbox starts, **Then** the
   listed tools are installed and on the agent's path.
2. **Given** a second start of the same project, **When** the sandbox starts, **Then** tools
   installed in the first session are reused.
3. **Given** the developer asks to reset the cache, **When** the sandbox next starts, **Then** it
   starts from an empty cache.
4. **Given** the developer asks to rebuild, **When** the sandbox next starts, **Then** the image is
   built again from scratch, picking up newer agent versions.

---

### User Story 5 - Debug the sandbox from a shell (Priority: P3)

The developer runs `sandbox shell` and gets a shell in the same environment the agent would get,
to look at what is installed or why something fails.

**Why this priority**: Helpful for troubleshooting, not needed for daily use.

**Independent Test**: Run `sandbox shell`, check the working folder is the project, the user matches
the host user's ids, and the agent's config is in place.

**Acceptance Scenarios**:

1. **Given** a project folder, **When** the developer runs `sandbox shell`, **Then** a shell opens
   in the project inside a sandbox with the same mounts, user and limits as an agent session.

---

### Edge Cases

- Docker is not installed or not running: the command exits with a clear message and starts nothing.
  Install is not affected when Docker is absent.
- The project path does not exist or is not a folder: clear message, nothing started.
- The developer runs `sandbox` from their home folder or `/`: the command refuses, because the whole
  point is to limit the agent to one project.
- The project path contains spaces.
- The default container network has no internet access (as on the developer's Linux machine): the
  developer can choose a different network mode for that run or for that machine.
- Two sandboxes run at the same time on different projects, or on the same project.
- The host user's ids clash with a user that already exists in the base image (for example id 1000
  on Linux, or group id 20 on macOS).
- The agent tries to gain root inside the container: there is no way to do so.
- A host config file is a symlink into another folder (for example dotfiles managed elsewhere).
- The agent edits files in the project that the developer later runs on the host (build scripts,
  package scripts, `.envrc`, tool config). These changes are visible in a diff; the README tells the
  developer to review them before running anything. Changes to git hooks and git config do not
  show in a diff; this risk is accepted and documented (FR-006a).
- The project's remote URL contains an embedded token: the agent could push with it. Documented.
- The project is a git worktree, whose `.git` file points to a folder outside the project. Git
  commands inside the sandbox may not work for that project; this is documented, not solved.

## Requirements *(mandatory)*

### Functional Requirements

**Starting and choosing**

- **FR-001**: The command MUST accept an optional agent name (`claude`, the default, or `opencode`),
  `shell`, and an optional project path that defaults to the current folder.
- **FR-002**: The agent MUST start with its permission prompts turned off, in the project folder.
- **FR-003**: The command MUST refuse to use the developer's home folder or the filesystem root as
  the project.
- **FR-004**: Each session MUST run in a new container that is removed when the session ends.
- **FR-005**: Several sandboxes MUST be able to run at the same time.

**Isolation**

- **FR-006**: The project folder MUST be the only host location the sandbox can write to.
- **FR-006a**: The project's git folder stays writable so the agent can commit. The README MUST
  warn that the agent can therefore change git hooks and git config, which git runs on the host and
  which do not show up in a diff.
- **FR-007**: The sandbox MUST run as an ordinary user with the same user and group ids as the
  developer on the host, so files it creates are owned by the developer.
- **FR-008**: The sandbox MUST NOT run privileged, MUST hold no extra kernel capabilities, MUST NOT
  be able to gain new privileges, and MUST NOT include any way to become root (no sudo).
- **FR-009**: The sandbox MUST NOT have access to the container engine's control socket.
- **FR-010**: The sandbox MUST NOT receive SSH keys, an SSH agent, git credential helpers, GitHub
  CLI tokens or cloud provider credentials. The only credentials passed in are the agents' own
  model logins.
- **FR-011**: The sandbox MUST NOT expose any ports on the host.

**Config and login**

- **FR-012**: The host's Claude Code config (`~/.claude` and `~/.claude.json`) and OpenCode config
  and login (`~/.config/opencode` and OpenCode's login file) MUST be available to the agent when
  present, and MUST be read-only from the sandbox's side. The agent MAY change its working copy for
  the session.
- **FR-013**: Missing host config MUST be skipped without error.
- **FR-014**: Claude Code login tokens set in the developer's environment (`CLAUDE_CODE_OAUTH_TOKEN`,
  `ANTHROPIC_API_KEY`) MUST be passed to the sandbox, because on macOS the Claude Code login lives in
  the system keychain and is not in the config folder.

**Toolchains and caching**

- **FR-015**: The sandbox MUST include mise. When the project has a mise config or `.tool-versions`
  file, the listed tools MUST be installed before the agent starts. A failure to install MUST be
  shown but MUST NOT stop the agent from starting.
- **FR-016**: Tool installs and package downloads MUST be kept in a persistent cache that survives
  the container. Each project MUST have its own cache, so a project cannot tamper with tools that
  another project's sandbox will run.
- **FR-017**: The developer MUST be able to clear the cache and to force a rebuild of the sandbox
  image.
- **FR-018**: The sandbox image MUST be built automatically on first use and rebuilt when its
  definition in the repo changes.

**Network**

- **FR-019**: The sandbox MUST have outbound internet access on the container engine's default
  network.
- **FR-020**: The developer MUST be able to choose a different network mode, both for one run and as
  a machine-wide default.

**Platform and project rules**

- **FR-021**: The command MUST work on macOS and Linux (constitution I).
- **FR-022**: Docker is an optional tool. When it is missing, the command MUST exit with a clear
  message, and install MUST still succeed (constitution I).
- **FR-023**: The README MUST document the command, its options, what is and is not isolated
  (including FR-006a), and how to give the agent a login token on macOS.

### Key Entities

- **Sandbox session**: one run of an agent or shell in a new container for one project. Ends when
  the agent or shell exits.
- **Sandbox image**: the environment every session starts from, with the agents and mise installed,
  built locally for the developer's user and group ids.
- **Tool cache**: persistent storage for installed tools and package downloads, one per project,
  shared by all sessions of that project.
- **Host agent config**: the developer's existing Claude Code and OpenCode config and logins.
  Read-only to the sandbox.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: From a project folder with the image already built, one command with no arguments
  starts Claude Code in under 5 seconds when the project has no tools to install.
- **SC-002**: In an automated test, an agent-equivalent process in the sandbox fails to write to
  each host location it tries outside the project (home folder, agent config, other projects),
  and fails to become root.
- **SC-003**: Every file created in the project by the sandbox is owned by the developer's user and
  group on both macOS and Linux.
- **SC-004**: After a session that changed the agent's config, the host config files are
  byte-for-byte unchanged.
- **SC-005**: A second start of a project whose tools were installed in an earlier session
  downloads nothing.
- **SC-006**: A clean install on a machine without Docker completes successfully.

## Assumptions

- Docker (Docker Desktop on macOS, Docker Engine on Linux) is the container engine. Other engines
  are out of scope.
- Full outbound internet is accepted for now, as described in the request. Limiting outbound traffic
  to an allowlist, and blocking the host and local network, is a later feature. This feature should
  not make that harder.
- Container isolation is enough for this threat model: an over-eager or misled agent, not an
  attacker with a container escape. A VM-based sandbox was considered and set aside.
- The agents are installed at their latest version when the image is built. Rebuilding updates them.
  Pinning agent versions is not needed.
- The sandbox needs network access to build the image and install tools, so it does not work in an
  airgapped environment and is not carried by pack.
- A cache per project costs disk space and a first-time download per project. A single shared cache
  would be faster for new projects, but an agent in one project could replace a tool binary that
  another project's sandbox later runs, so it is not used.
- The developer's git name and email are passed in so commits made in the sandbox carry the
  developer's identity. They are not secrets.
