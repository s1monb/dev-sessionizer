# Feature Specification: Bounded Repo Scan for the Project Picker

**Feature Branch**: `002-bounded-repo-scan`

**Created**: 2026-10-30

**Status**: Draft

**Input**: User description: "dev-script is taking ages to resolve the different paths. Is there a way to make the search less recursive?"

## Context

The project picker (`dev`) builds its list by searching every folder under each root in the
roots file until it finds a git repo. Folders that are not repos are searched all the way down.
On the author's machine, one root holding 15 repos takes about 13 seconds to list. Almost all of
that time goes to walking large non-repo folders: one of them has about 4,900 subfolders and
no repo inside it. The baseline requirement (001, SC-005) of under 3 seconds is met in the test
sandbox but not on a real machine.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Picker opens quickly on a real machine (Priority: P1)

A developer runs `dev` and the list of projects appears almost at once, even when the roots
contain large folders that are not repos (build output, dependency caches, downloaded data,
plain document folders).

**Why this priority**: This is the complaint. A picker that takes many seconds to open stops
being the fast way into a project.

**Independent Test**: Make a root with repos at the usual depth next to a non-repo folder that
has thousands of nested subfolders. Run `dev --list` and time it. It must finish within the
target, and the large folder must not slow it down noticeably.

**Acceptance Scenarios**:

1. **Given** a root with repos one or two levels down and a non-repo folder with thousands of
   nested subfolders, **When** the developer lists projects, **Then** every repo within the
   search depth is listed and the listing finishes in under 1 second.
2. **Given** the author's current roots file (one root, 15 repos), **When** the developer lists
   projects, **Then** the listing finishes in under 1 second, down from about 13 seconds.
3. **Given** a repo that contains nested repos, **When** the developer lists projects, **Then**
   only the outer repo is listed, as today.

---

### User Story 2 - Reach deeper repos when a root needs it (Priority: P2)

Some roots hold repos deeper than usual, such as worktree checkouts at
`<root>/<org>/worktrees/<project>/<name>/<repo>`. The developer can raise the search depth for
that one root in the roots file, without slowing down every other root.

**Why this priority**: The default depth will hide a few deep repos that are listed today. This
gives the developer a way to get them back. It is not needed for the speed-up itself.

**Independent Test**: Add a root whose repos sit five levels down, with no depth set. Check they
are not listed. Set a depth of 5 for that root. Check they are now listed, and that other roots
still use the default.

**Acceptance Scenarios**:

1. **Given** a roots file entry with no depth set, **When** the picker lists projects, **Then**
   it searches that root to the default depth.
2. **Given** a roots file entry with a depth set, **When** the picker lists projects, **Then** it
   searches that root to the given depth and every other root to its own depth.
3. **Given** a roots file entry with a depth that is not a positive whole number, **When** the
   picker runs, **Then** it exits with a clear message naming the bad line, without running
   anything from the file.

---

### Edge Cases

- A repo deeper than its root's depth is not listed. Opening it directly with `dev PATH` still
  works.
- A root entry that is itself a repo is not listed. This is the current behaviour; the search
  starts one level below the root.
- A root that does not exist is skipped silently, as today.
- Folders the user cannot read are skipped without an error message.
- Worktrees and submodules (where `.git` is a file, not a folder) count as repos, as today.
- Roots files written for the current version (paths only, no depth) keep working unchanged.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The picker MUST NOT search deeper than the search depth of the root it is in. Depth
  is counted in folders below the root, so `<root>/<org>/<repo>` is depth 2.
- **FR-002**: The default search depth MUST be 3. This covers the `<org>/<repo>` layout used by
  the clone helper with one level to spare.
- **FR-003**: A roots file entry MAY set its own search depth. Entries without one MUST use the
  default. The format MUST be backwards compatible: every roots file valid today MUST still be
  valid and give the same results for repos within the default depth. The one exception is a root
  whose last folder name contains `:`. That suffix is read as a depth and rejected with an error
  (FR-006). Such names are not allowed in Finder on macOS and are rare on Linux; the README
  documents this.
- **FR-004**: The picker MUST stop descending as soon as it finds a repo, so nested repos and the
  contents of repos are never searched. This is unchanged from today.
- **FR-005**: The cost of the search MUST NOT grow with the number of non-repo folders deeper
  than the search depth.
- **FR-006**: A bad depth value MUST stop the picker with a message naming the roots file and the
  offending line. Nothing in the roots file may be executed (keeps 001 FR-022).
- **FR-007**: The output of `dev --list` MUST keep its current format: one absolute repo path
  per line.
- **FR-008**: The picker MUST keep working on macOS and Linux with the stock tools on each
  (constitution I) and on bash 3.2.
- **FR-009**: The roots file format, including how to set a depth, MUST be documented in the
  README and in the error shown when the roots file is missing.

### Key Entities

- **Roots file entry**: one line in `~/.devconfig`. It holds a folder path, with `~` and
  environment variables expanded, and an optional search depth.
- **Search depth**: how many folder levels below a root the picker looks for repos.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: On the author's machine, `dev --list` finishes in under 1 second, down from about
  13 seconds.
- **SC-002**: With a root holding 200 repos at depth 2 plus a non-repo folder of 5,000 nested
  subfolders, listing takes under 1 second.
- **SC-003**: After adding 10,000 more nested folders below the search depth, listing returns
  the same repos and still takes under 1 second.
- **SC-004**: Every repo the current picker lists at depth 3 or less is still listed, with no
  change to the roots file.
- **SC-005**: Each deep repo the default hides can be listed again by adding a depth to one line
  of the roots file.

## Assumptions

- Most repos live at depth 2 or 3 under a root. The clone helper (`dev-gc`) puts them at
  `<host>/<org>/<repo>` under `$HOME`, which is depth 2 under a `~/<host>` root.
- Losing deep repos by default, such as the worktree checkouts at depth 5 on the author's
  machine, is acceptable because a per-root depth can bring them back (User Story 2).
- No list of folder names to skip (such as dependency caches) is added. A depth limit is enough
  and simpler (constitution V).
- No caching of results between runs. The search should be fast enough without one.
- The exact syntax for setting a depth on a roots file line is decided in planning. It must not
  clash with paths that contain spaces.
