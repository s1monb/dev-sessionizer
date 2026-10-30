# Feature Specification: Baseline the Existing Toolkit

**Feature Branch**: `001-baseline-existing-toolkit`

**Created**: 2026-10-30

**Status**: Draft

**Input**: User description: "lets close the gap on the already existing functionality in this repo
that has never been planned or specced through spec-driven development. But before we do that, we
should look at how the current functionality is developed and how we could improve."

**Context**: The assessment of how the toolkit is built today, with each finding mapped to the
constitution, is in [current-state.md](./current-state.md). This spec turns that existing
behaviour into explicit requirements and closes the gaps the assessment found.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Verify a change on both platforms before it lands (Priority: P1)

As the maintainer, before I merge a change I run one verification step. It tells me whether the
toolkit still installs and works on macOS and on Linux, so I stop finding breakage only when I
sit down at another machine.

**Why this priority**: Today nothing is verified. Every other story in this spec depends on being
able to prove that behaviour holds on both platforms. This is the "improve how it is developed"
part of the request, and it comes first.

**Independent Test**: Run the verification step on a clean checkout of the current code. It must
finish with a clear pass/fail result for each platform, and it must catch a planted defect (for
example, a script that uses a flag only available on one platform).

**Acceptance Scenarios**:

1. **Given** a clean checkout, **When** the maintainer runs the verification step, **Then** it
   reports pass/fail separately for the macOS and Linux checks within 5 minutes.
2. **Given** a change that adds a script with a syntax or portability defect, **When**
   verification runs, **Then** it fails and names the file and the problem.
3. **Given** verification passes, **When** it finishes, **Then** the maintainer's real home
   directory is unchanged, because all checks ran against a throwaway home.

---

### User Story 2 - Install or update a machine with one command (Priority: P1)

On a new or existing macOS or Linux machine, I clone the repo and run one command. I get my shell,
prompt, tmux, Neovim with its plugins, and my personal scripts. Running the same command later
updates everything to the repo's current version.

**Why this priority**: This is the main reason the toolkit exists.

**Independent Test**: In a throwaway home on each platform, run the install command twice. After
both runs, the shell opens with the shared prompt, tmux starts with the bundled config, and Neovim
opens with every vendored plugin loaded and no errors.

**Acceptance Scenarios**:

1. **Given** a machine that has the documented pre-requisites, **When** the install command runs,
   **Then** every component is in place and a new shell shows the shared prompt.
2. **Given** an installed machine, **When** the install command runs again, **Then** the result is
   the same as after the first run, and only repo-managed files have changed.
3. **Given** a machine missing a hard pre-requisite, **When** install runs, **Then** it stops
   before changing anything and names each missing item.
4. **Given** an optional tool (for example a cluster CLI) is absent, **When** install runs,
   **Then** that tool's extras are skipped and install still succeeds.

---

### User Story 3 - Keep machine-local customisations across updates (Priority: P2)

I tweak things on a single machine: an extra alias, an editor setting, a tmux key, a local
script. Those tweaks survive every update and take priority over the shared defaults.

**Why this priority**: Today an update silently wipes local edits to everything except the shell
rc file. That breaks the "overwriteable" principle and erodes trust in running updates.

**Independent Test**: Add a local override for the shell, the editor and tmux, then run install
again. Each override is still present and still active.

**Acceptance Scenarios**:

1. **Given** a local override file exists for a component, **When** install runs, **Then** the
   file is untouched and its settings take effect after the shared defaults.
2. **Given** a user edited a repo-managed file in place, **When** install runs, **Then** the file
   is replaced, and the docs say where such edits belong instead.
3. **Given** no override exists, **When** the component loads, **Then** it behaves exactly as the
   shared defaults define.

---

### User Story 4 - Move the environment to an airgapped machine (Priority: P2)

On a connected machine, I produce a single archive. I copy it to a machine with no internet and
unpack it there with one command. I end up with the same working environment, including editor
language tooling.

**Why this priority**: This is a stated core use case. Today it is broken in two ways: the archive
layout is wrong, and the bundled task runner only runs on Linux x86-64.

**Independent Test**: Pack on one machine. Unpack in a throwaway home with network access
disabled, once on macOS and once on Linux. Neovim then opens with plugins and the previously
installed language servers working.

**Acceptance Scenarios**:

1. **Given** an installed machine, **When** pack runs, **Then** it produces exactly one archive
   file and leaves no temporary folders behind.
2. **Given** that archive on a machine with no network, **When** the user runs the documented
   unpack command, **Then** the environment is installed and runtime state is restored, with no
   network access attempted.
3. **Given** a machine that has never run the editor (no runtime state), **When** pack runs,
   **Then** it still succeeds and the archive contains just the config.
4. **Given** the target has a different OS or CPU architecture from the source, **When** the user
   unpacks, **Then** the install steps run. Any runtime state that doesn't match the target
   platform is reported, not silently restored.

---

### User Story 5 - Jump into a project session (Priority: P3)

From any shell or tmux session, I press a key or run a command. I fuzzy-pick a project from my
configured roots and land in a dedicated tmux session for it.

**Why this priority**: This is the daily-use feature the repo is named after. It mostly works
today, but it has defects that are known and easy to fix.

**Independent Test**: With a roots file listing two folders that contain git repos, run the
picker, choose a project, and confirm a session opens in that folder. Repeat from inside tmux.

**Acceptance Scenarios**:

1. **Given** a roots file with valid entries, **When** the picker runs, **Then** every git repo
   under those roots is listed and choosing one opens a session in it.
2. **Given** any project name, including ones with dots or spaces, **When** a session is created,
   **Then** the session name is always a valid tmux target.
3. **Given** the roots file is missing or a required tool is absent, **When** the picker runs,
   **Then** it prints what is missing and how to fix it, and exits without error noise.
4. **Given** the user cancels the picker, **When** it exits, **Then** no session is created.

---

### User Story 6 - Use the bundled helper commands (Priority: P3)

I use two small helpers that ship with the toolkit: cloning a repo into a host/path layout, and
toggling the caps/escape key swap. Helpers I no longer use (the cluster-context helper, the
containerised AI runner and a personal SSH alias) are gone.

**Why this priority**: These are useful, but each serves a narrow purpose. Their main requirement
is not to break or confuse other platforms, and the toolkit should carry nothing unused.

**Independent Test**: Run each helper's help or usage path on macOS and Linux. Each one either
works, or explains that it doesn't apply to this platform and exits cleanly.

**Acceptance Scenarios**:

1. **Given** a git URL in SSH or HTTPS form, **When** the clone helper runs, **Then** the repo is
   cloned to `~/<host>/<path>`, and an existing destination prompts for a new name.
2. **Given** a helper that only applies to one platform or desktop, **When** it runs elsewhere,
   **Then** it exits with a clear "not supported here" message.
3. **Given** a fresh install, **When** the user looks in the installed scripts, PATH and docs,
   **Then** there is no trace of the removed helpers.

### Edge Cases

- Install is interrupted halfway: re-running it must complete cleanly without manual cleanup.
- The user's login shell is not bash: the shared setup still loads in new tmux panes, and the docs
  say how to switch the login shell.
- A roots file entry points to a folder that does not exist: the picker skips it and still lists
  the other entries.
- A vendored submodule is not initialised (for example, the repo was downloaded as a zip):
  install detects this and stops with instructions.
- A file in the archive has the same name as one of the user's override files: unpack must not
  overwrite the override.
- The archive is unpacked on a machine that already has an older install: the result is identical
  to unpacking onto a clean machine, with overrides kept.
- Runtime state already on the target (for example, language servers installed locally) is replaced
  by the archive's, not merged.

## Requirements *(mandatory)*

### Functional Requirements

**Development workflow**

- **FR-001**: The repo MUST provide one verification command. It checks every shipped script for
  syntax and portability problems, and runs an install smoke test in a throwaway home.
- **FR-002**: Verification MUST be runnable for both macOS and Linux, and MUST report results per
  platform.
- **FR-003**: Verification MUST NOT read or modify the maintainer's real home directory.
- **FR-004**: The docs MUST use one consistent name for each command, and MUST match the
  vocabulary in `CONTEXT.md`.

**Install and update**

- **FR-005**: One command MUST both install and update all components on macOS and Linux.
- **FR-006**: Install MUST be idempotent and MUST change only repo-owned paths.
- **FR-007**: Install MUST check hard pre-requisites before making any change, and MUST list
  everything missing at once.
- **FR-008**: The README MUST list every hard and optional pre-requisite that a shipped component
  uses.
- **FR-009**: Optional integrations MUST be skipped silently when their tool is absent.
- **FR-010**: Install MUST NOT need network access once the repo and its vendored dependencies are
  present.

**Overrides**

- **FR-011**: Each of the shell, prompt/aliases, editor, terminal multiplexer and personal scripts
  MUST have a documented local override location.
- **FR-012**: Override locations MUST be created at most once (when absent) and never overwritten
  afterwards.
- **FR-013**: Overrides MUST load after the shared defaults so they take precedence.
- **FR-014**: Personal or machine-specific settings (for example, SSH shortcuts with usernames)
  MUST live in override locations, not in shared files.

**Transport**

- **FR-015**: Pack MUST produce one archive that contains the repo's installable files, vendored
  dependencies, the unpack script, and the editor's runtime state if any exists.
- **FR-016**: Pack MUST succeed whether or not runtime state exists, and MUST leave no temporary
  files behind.
- **FR-017**: There MUST be exactly one documented unpack command. It MUST work offline on macOS
  and Linux, and MUST NOT overwrite override files.
- **FR-018**: Install, update, pack and unpack MUST be plain shell scripts that need nothing beyond
  the documented pre-requisites. No task-runner binary is shipped or required on the target, and
  the committed runner binary is removed. A task-runner file, if one is kept, MAY only call these
  scripts as a convenience; it MUST NOT contain logic of its own.

**Session tools**

- **FR-019**: The project picker MUST list git repos under the roots in the user's roots file, and
  MUST open or switch to a tmux session for the chosen one, both inside and outside tmux.
- **FR-020**: Session names MUST always be valid tmux targets.
- **FR-021**: There MUST be exactly one session tool. The multi-pane AI-assistant session tool
  (`claude-session`) and its duplicated picker MUST be removed.
- **FR-022**: The picker MUST NOT execute arbitrary code from the roots file. Only home-directory
  and environment-variable expansion is allowed.

**Helpers and content**

- **FR-023**: Helpers that only apply to one platform or desktop MUST detect an unsupported
  environment and exit with a clear message.
- **FR-024**: The following unused items MUST be removed from the repo, from install, from PATH and
  from the docs: the cluster-context helper (`kubectx-create`), the personal SSH alias (`ifi`), and
  the containerised AI runner (`ai`, `ai-build`, `ai-init` and their container definition).
- **FR-025**: Unused or duplicated content MUST be removed. This includes the stale plugin lock
  file and the copied language-server configs that the vendored plugin already provides.
- **FR-026**: Each vendored dependency MUST be vendored in exactly one consistent way and pinned to
  an explicit version.
- **FR-027**: The remaining niche helpers stay as shipped defaults: the caps/escape swap and the
  repo clone helper. Each one MUST follow FR-023.

### Key Entities

- **Component**: one installable piece (shell setup, prompt theme, tmux, editor, scripts, k9s). It has a repo-owned install location and an optional override location.
- **Override file**: a user-owned file the toolkit creates at most once and never rewrites.
- **Vendored dependency**: third-party code bundled in the repo at a pinned version.
- **Runtime state**: artefacts the tools produce on a machine (language servers, parsers, editor
  state) that pack carries and unpack restores.
- **Archive**: the single file produced by pack, used for transfer.
- **Roots file**: the user's list of folders the project picker scans.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: On a fresh macOS machine and a fresh Linux machine that have the pre-requisites,
  going from clone to a working environment takes one command and under 2 minutes.
- **SC-002**: Running install three times in a row produces identical repo-managed files, and zero
  user override files are modified.
- **SC-003**: Verification catches 100% of a planted set of defects (syntax error, one-platform
  flag, missing pre-requisite, overwritten override). A clean run takes under 5 minutes.
- **SC-004**: An archive made on one machine unpacks to a working editor with language tooling on
  an offline macOS and an offline Linux machine, with zero network requests.
- **SC-005**: Picking a project and landing in its session takes under 3 seconds on a roots file
  covering 200 repos.
- **SC-006**: Repo-tracked files that are never used drop to zero, and the tracked size of the
  editor config shrinks by at least 90%.
- **SC-007**: Every shipped helper, run on an unsupported platform, exits with a clear message
  instead of an unexplained error.

## Assumptions

- The only user is the maintainer, on their own machines. No multi-user or team distribution is in
  scope.
- "Linux" means mainstream glibc distributions (Debian/Ubuntu/Arch family) on x86-64 and arm64.
  "macOS" means current releases on Apple silicon and Intel.
- Bash stays the supported shell. Other shells are out of scope, apart from documenting how to
  switch.
- Verification may use containers for the Linux checks. The macOS check runs on a real Mac (the
  maintainer's machine or a hosted runner).
- Neovim (≥ 0.12), tmux (≥ 3.2), fzf, git and bash remain user-installed pre-requisites. The toolkit configures
  them but does not install them.
- The editor's language servers are fetched while online and carried by pack. Fetching them
  offline is out of scope.
- Offline unpack is proven automatically on Linux (`--network none`). On macOS it relies on the
  static network check across all entry scripts plus the same scripts; macOS has no cheap
  network sandbox.
- This spec covers existing functionality only. New tools or features need their own specs.
- "AI stuff" to remove covers both the containerised runner under the AI config folder and the
  multi-pane `claude-session` tool.

## Clarifications

### Session 2026-10-30

- Q: How should unpack get a task runner on an airgapped machine? → A: It doesn't need one.
  Install, update, pack and unpack become plain shell scripts (FR-018).
- Q: What scope for personal/niche helpers? → A: Remove `kubectx-create`, the `ifi` alias and the
  containerised AI runner because they are unused (FR-024). Keep the rest with platform guards
  (FR-027).
- Q: Does `claude-session` stay? → A: No, remove it. `dev` is the only session tool (FR-021).
