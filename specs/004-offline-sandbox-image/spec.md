# Feature Specification: Offline Sandbox Image and Default Agent

**Feature Branch**: `004-offline-sandbox-image`

**Created**: 2026-11-03

**Status**: Draft

**Input**: User description: "I want to be able to build sandbox image for another computer with
another uid and gid. It needs it to be able to work without internet. If there are other things that
need internet when using opencode let me know. Also, it would be cool if we could set default
sandbox through the sandbox.env config file so I dont have to write sandbox opencode each time"

## Clarifications

### Session 2026-11-03

- Q: Where does the image file go? → A: Inside the pack archive. `./pack.sh` builds the image for
  the target's user id and group id and puts it in the same archive; `unpack.sh` loads it.
- Q: Is a model server and OpenCode config available on the airgapped target? → A: Yes. The
  developer has models and an OpenCode config on the target, so neither is in scope.
- Q: Can the warning Claude Code shows when permissions are bypassed be skipped? → A: Yes, it is in
  scope: the sandbox already is the safety measure the warning asks for.

## Context

Today the agent sandbox (feature 003) builds its image on the machine that uses it. The build uses
the developer's user and group ids and downloads the base system, the agents and mise from the
internet. Before starting a session the command checks whether the image matches the repo and the
current user, and rebuilds it if not. On an airgapped machine both steps fail, so the sandbox
cannot be used there. The 003 spec says the sandbox does not work airgapped and is not carried by
pack.

This feature changes that. When packing, the developer gives the target machine's user id and
group id. Pack builds the sandbox image for those ids and puts it in the archive. Unpack on the
target loads it, and `sandbox` uses it without trying to build or download anything.

It also lets the developer choose the default agent in `~/.config/local/sandbox.env`, so that
`sandbox` with no agent name starts OpenCode on a machine where that is the agent they use, and it
stops Claude Code from asking the developer to confirm bypass-permissions mode on every start.

### What else needs internet when OpenCode runs in the sandbox

Even with the image in place, these parts of a session reach out to the network. Each is handled,
turned off, or documented (FR-013 to FR-015). Planning checks this list against the OpenCode
version in the image.

| # | What | Effect when offline | Handling in this feature |
|---|------|---------------------|--------------------------|
| 1 | The model provider | The agent cannot answer | Available on the target (out of scope) |
| 2 | OpenCode's model catalog download at start | Slow start or warning | Turned off in sessions on a packed image. Models come from the target's own OpenCode config |
| 3 | OpenCode's update check | Slow start or warning | Turned off in all sandboxes, since the image is not updated in place |
| 4 | Plugins listed in the OpenCode config, installed when OpenCode starts | Plugins missing, possible start failure | Documented. The target's OpenCode config is the developer's responsibility |
| 5 | Language servers OpenCode downloads the first time it opens a file of that language | No code intelligence for that language | Download turned off in sessions on a packed image. Documented |
| 6 | Formatters and MCP servers started through package runners that download on demand, and remote MCP servers | Those formatters or MCP servers fail | Documented |
| 7 | Web fetch, web search and share links in OpenCode | Those tools fail | Documented |
| 8 | Project tools pinned for mise | Not installed. The agent may not be able to build or test | Documented. The session still starts (as in 003) |
| 9 | Packages the agent installs while working (npm, pip, Go modules, Cargo) | Fail unless the target has a local mirror | Documented |
| 10 | Rebuilding the image (`--rebuild`, or newer image files after a repo update) | Build fails | No automatic rebuild for a packed image (FR-008). `--rebuild` fails with a clear message |

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Pack the sandbox image for another machine (Priority: P1)

On a connected machine the developer runs pack and gives the target machine's user id and group id.
Pack builds the sandbox image for those ids and puts it in the same archive as the rest of the
environment. The developer copies the one archive to the airgapped machine.

**Why this priority**: Nothing else in this feature works without it.

**Independent Test**: On a connected machine with user id 1000, pack with user id 1500 and group
id 1500. Check that one archive is written and that it holds the image. Load the image from the
archive in a test setup and check the agent user inside has ids 1500:1500, and that Claude Code,
OpenCode and mise run.

**Acceptance Scenarios**:

1. **Given** a connected machine, **When** the developer packs with user id U and group id G,
   **Then** one archive is written that holds the environment and a sandbox image whose agent user
   has ids U and G.
2. **Given** a target with a different processor architecture from the build machine, **When** the
   developer names the target's architecture when packing, **Then** the image is built for that
   architecture.
3. **Given** a user id or group id that is not a number or is 0, or only one of the two is given,
   **When** the developer packs, **Then** pack exits with a clear message and writes no archive.
4. **Given** a user id that clashes with a user already in the base image, **When** the developer
   packs, **Then** pack fails with the same clear message as a local build (feature 003) and writes
   no archive.
5. **Given** the developer packs without giving any ids, **When** pack runs, **Then** it works as
   today: no image is built, Docker is not needed, and the archive holds no image.
6. **Given** ids are given but Docker is missing or not running, **When** the developer packs,
   **Then** pack exits with a clear message and writes no archive.

---

### User Story 2 - Use the sandbox on an airgapped machine (Priority: P1)

On the airgapped machine the developer extracts the archive and runs unpack as today. Unpack also
loads the sandbox image. The developer then runs `sandbox` (or `sandbox opencode`) in a project.
The session starts using the packed image. The command does not try to build, pull or download
anything, and does not hang waiting for the network.

**Why this priority**: This is the reason for packing the image.

**Independent Test**: Unpack an archive with an image on a machine (or test setup) with no outbound
network, where the user ids match the image. Run `sandbox shell -- -c 'id; claude --version;
opencode --version'` and check it succeeds without any build. Run `sandbox opencode` with the
target's model server and check OpenCode starts and answers.

**Acceptance Scenarios**:

1. **Given** an archive with an image, **When** the developer runs unpack on the target with
   Docker running, **Then** the image is loaded with no network access, replacing an earlier loaded
   image.
2. **Given** an archive with an image, **When** unpack runs on a target where Docker is missing or
   not running, **Then** install and runtime state are restored as usual, and unpack prints a
   message saying the image was not loaded and how to load it later.
3. **Given** an archive with an image built for other ids than the user running unpack, **When**
   unpack runs, **Then** it loads the image and warns that `sandbox` will refuse to use it for this
   user.
4. **Given** a packed image whose ids match the current user, **When** the developer runs
   `sandbox`, **Then** the session starts with that image and no build is attempted, even when the
   image files in the repo differ from the ones the image was built from.
5. **Given** a packed image whose ids do not match the current user, **When** the developer runs
   `sandbox`, **Then** it exits with a message naming both sets of ids and starts nothing.
6. **Given** a packed image built from older image files than the installed repo, **When** a
   session starts, **Then** it starts, and a one-line notice says the image is older.
7. **Given** a packed image on the target, **When** OpenCode starts in the sandbox, **Then** it
   does not wait on the blocked network calls in rows 2, 3 and 5 of the table in Context.
8. **Given** a packed image, **When** the developer runs `sandbox --rebuild`, **Then** it explains
   that the image was packed on another machine and must be repacked there, and starts nothing.

---

### User Story 3 - Choose the default agent in sandbox.env (Priority: P2)

The developer adds one line to `~/.config/local/sandbox.env` naming their usual agent. From then on
`sandbox` with no agent name starts that agent. Naming an agent on the command line still wins.

**Why this priority**: Saves typing on every start, but the feature works without it.

**Independent Test**: Put the setting for OpenCode in `sandbox.env`. Run `sandbox` and check
OpenCode starts. Run `sandbox claude` and check Claude Code starts. Run `sandbox shell` and check a
shell starts.

**Acceptance Scenarios**:

1. **Given** `sandbox.env` names `opencode` as default, **When** the developer runs `sandbox` with
   no agent name, **Then** OpenCode starts.
2. **Given** `sandbox.env` names `opencode` as default, **When** the developer runs `sandbox claude`
   or `sandbox shell`, **Then** the named one starts.
3. **Given** no default in `sandbox.env`, or no `sandbox.env`, **When** the developer runs
   `sandbox`, **Then** Claude Code starts, as today.
4. **Given** `sandbox.env` names an agent that is not supported, **When** the developer runs
   `sandbox` with no agent name, **Then** it exits with a message naming the file, the bad value and
   the supported agents, and starts nothing.
5. **Given** an existing `sandbox.env` created by an earlier install, **When** install runs again,
   **Then** the file is not changed. A fresh install's template shows the setting as a commented
   example.

---

### User Story 4 - No bypass-permissions warning in Claude Code (Priority: P3)

The developer runs `sandbox` and Claude Code starts straight into the session, without first asking
them to confirm that permissions are bypassed.

**Why this priority**: The warning is an extra step on every start, but it does not block use.

**Independent Test**: With a host Claude Code config that has never accepted bypass-permissions
mode, run `sandbox` and check no confirmation is shown. Check the host config is unchanged after
the session, and that Claude Code on the host still shows the warning when run with permissions
bypassed.

**Acceptance Scenarios**:

1. **Given** any host Claude Code config, **When** Claude Code starts in the sandbox, **Then** it
   does not ask to confirm bypass-permissions mode.
2. **Given** a session has ended, **When** the developer runs Claude Code on the host, **Then** the
   host's own warning behaviour is unchanged.

---

### Edge Cases

- Unpack on a target where the archive's runtime state is skipped because the platform differs:
  the image is still loaded when its architecture matches the target. An image for another
  architecture is not loaded, with a clear message.
- The target already has a locally built image (it was once connected): the packed image replaces
  it. To go back to local builds, the developer removes the packed image; the next `sandbox`
  builds locally, as documented.
- The target user is root (id 0): refused when packing, as `sandbox` already refuses to run as
  root.
- The target's group id is taken by an existing group in the base image (e.g. 20 on macOS): reused,
  as in a local build.
- Not enough disk space for the archive, or the output path is not writable: clear message, no
  partial archive left behind.
- The default agent line in `sandbox.env` has surrounding spaces or quotes: the file is read as
  plain `KEY=value` lines (it is also passed to Docker), so quotes are part of the value and the
  value is rejected with the message from scenario 3.4.
- The default agent setting also arrives inside the container through the env file. This is
  harmless.
- The OpenCode config on the target lists a plugin that is not installed: OpenCode tries to
  download it and fails; this is covered by the documented list in Context.

## Requirements *(mandatory)*

### Functional Requirements

**Packing the image**

- **FR-001**: Pack MUST accept the target's user id and group id. When both are given, pack MUST
  build the sandbox image for those ids and include it in the same archive.
- **FR-002**: Pack MUST accept the target's processor architecture. The default is the build
  machine's architecture.
- **FR-003**: Pack MUST reject a non-numeric or zero id, or only one of the two ids, with a clear
  message, and MUST leave no partial archive on any failure (including a failed image build or a
  missing Docker).
- **FR-004**: Without ids, pack MUST behave as today and MUST NOT need Docker (constitution I).
- **FR-005**: The image MUST record the user id, group id, architecture and the version of the image
  files it was built from, and that it was packed for another machine.

**Unpacking and using the image**

- **FR-006**: Unpack MUST load the image from the archive when one is present, Docker is running and
  the architecture matches, without network access. A packed image replaces the previous one.
- **FR-007**: When Docker is missing or not running, or the architecture does not match, unpack MUST
  finish the rest of the unpack and print a message saying the image was not loaded and why. When
  the image's ids differ from the user running unpack, unpack MUST warn.
- **FR-008**: When a packed image matches the current user's ids, `sandbox` MUST use it and MUST NOT
  try to build, pull or download the image, even if the repo's image files are newer.
- **FR-009**: When the image was built for different ids, `sandbox` MUST exit with a message naming
  the image's ids and the current user's ids, and MUST start nothing.
- **FR-010**: When a packed image was built from older image files than the repo, `sandbox` MUST
  show a one-line notice and start anyway.
- **FR-011**: `sandbox --rebuild` with a packed image MUST explain that it must be repacked on a
  connected machine and MUST start nothing.
- **FR-012**: All isolation guarantees of feature 003 (FR-006 to FR-011 there) MUST hold unchanged
  for a packed image. Local builds on a connected machine MUST keep working as they do today.

**Network use in offline sessions**

- **FR-013**: OpenCode's automatic update check MUST be turned off in every sandbox session.
- **FR-014**: In a session that uses a packed image, OpenCode's model catalog download and automatic
  language server downloads MUST be turned off, so startup does not wait on blocked network calls.
- **FR-015**: The README MUST list everything in the table in Context: what still needs network on an
  airgapped target and what this feature turns off.

**Default agent**

- **FR-016**: `sandbox` MUST read a default agent setting (`claude` or `opencode`) from
  `~/.config/local/sandbox.env`. An agent or `shell` named on the command line MUST win over the
  setting. Without the setting the default stays `claude`.
- **FR-017**: An unsupported value MUST cause `sandbox` to exit with a message naming the file, the
  value and the supported agents, when the command line does not name an agent.
- **FR-018**: The `sandbox.env` template written by a fresh install MUST show the setting as a
  commented example. Install MUST NOT change an existing `sandbox.env` (constitution IV).
- **FR-019**: `sandbox --help` and the README MUST document the setting.

**Claude Code warning**

- **FR-020**: Claude Code in the sandbox MUST start without asking to confirm bypass-permissions
  mode. The host's Claude Code config MUST stay unchanged (003 FR-012).

**Platform and project rules**

- **FR-021**: Packing with an image MUST work from macOS and Linux build machines; the airgapped
  target is Linux (constitution I).
- **FR-022**: Install, pack without ids, and unpack MUST keep working on machines without Docker
  (constitution I). README MUST document the new pack options and the unpack behaviour.

### Key Entities

- **Packed sandbox image**: the sandbox image built for a named user id, group id and architecture,
  stored inside the pack archive and loaded by unpack.
- **Image identity**: what the image records about itself: user id, group id, architecture, version
  of the image files, and that it was packed for another machine. `sandbox` and unpack compare it
  with the current user, machine and repo.
- **Default agent setting**: one `KEY=value` line in `sandbox.env` naming the agent `sandbox` starts
  when no agent is named.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: One pack command on a connected machine and one unpack on an airgapped machine are
  enough to start a sandbox session there, with zero network requests made by unpack or by the
  `sandbox` command itself.
- **SC-002**: On the airgapped target, OpenCode in the sandbox starts in under 10 seconds for a
  project with no mise tools.
- **SC-003**: Every file the agent creates in the project on the target is owned by the target
  user's user and group.
- **SC-004**: An automated test covers: bad ids are refused by pack, an image with other ids is
  refused by `sandbox`, a matching packed image starts without building, `--rebuild` on a packed
  image is refused, and each default agent setting (absent, `claude`, `opencode`, invalid) gives the
  expected agent or error.
- **SC-005**: With the default agent set to OpenCode, starting OpenCode needs no agent name.
- **SC-006**: Starting Claude Code in the sandbox needs no confirmation step.
- **SC-007**: A clean install, and a pack without ids, complete successfully on a machine without
  Docker.

## Assumptions

- The airgapped target runs Linux with Docker Engine already installed. Getting Docker onto the
  target is out of scope.
- The target has its own model access and OpenCode config, set up by the developer. Neither is
  carried or changed by this feature.
- The developer knows the target user's ids (from `id -u` and `id -g` on that machine).
- The image includes the latest Claude Code, OpenCode and mise at pack time, as in 003. Updating
  them on the target means packing and unpacking again.
- The image adds several hundred megabytes to the archive. That is accepted; packs without ids stay
  as small as today.
- Project toolchains from mise are not carried to the target. Sessions start without them when they
  cannot be installed (003 FR-015). Carrying them is a possible later feature.
- The default agent is read from `sandbox.env` because that is where the developer already keeps
  sandbox settings. The file stays a plain `KEY=value` file that is never run by a shell.
- `SANDBOX_NETWORK` stays a shell variable as today.
- Skipping Claude Code's warning is acceptable because the sandbox is the isolation the warning asks
  for. How Claude Code is told to skip it is settled during planning.
