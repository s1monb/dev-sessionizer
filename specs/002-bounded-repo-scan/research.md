# Research: Bounded Repo Scan for the Project Picker

All measurements were taken on the author's machine (macOS, `/bin/bash` 3.2.57) on 2026-10-30
and 2026-10-31.

## R1. Where the time goes today

The current scan in `env/.config/bin/dev` is:

```bash
find "$root" -mindepth 1 -type d -exec test -e '{}/.git' ';' -print -prune
```

It has two costs:

1. **No depth limit.** Every folder that is not a repo is searched all the way down. Under
   `~/github.com`, `s1monb/presentation-editor` (no `.git`) holds about 4,900 subfolders.
2. **One process per folder.** `-exec test … ';'` starts a new process for every folder
   visited, including all ~4,900 above. Process start-up dominates the run time: `sys` is
   6.7 s of the 13.1 s wall time.

Measured: `dev --list` takes **13.1 s** and finds 15 repos (13 at depth 2, 2 at depth 5).

## R2. Scan method

**Decision**: Use a breadth-first scan in plain bash. It reads one level of folders at a time
with a glob (`"$dir"/*/`) and checks for `.git` with the bash `[[ -e ]]` test. A folder that
contains `.git` is printed and not searched further. Any other folder is queued for the next
level, until the root's depth is reached.

**Rationale**:
- It starts no processes: both the glob and the test are bash built-ins (FR-005, and the
  per-folder cost noted in the checklist).
- It prunes the way the current scan does: it stops at a repo, so nested repos and repo
  contents are never searched (FR-004).
- The depth limit is a loop bound, so folders below the depth are never read (FR-005, SC-003).
- It uses only bash 3.2 features, with no `find`/`awk` flag differences between macOS and
  Linux (FR-008, constitution I).
- Output comes out sorted within each level, which is a small bonus for the picker.

**Measured** (prototype, `/bin/bash` 3.2, `set -eu`):

| Case | Current | Bash scan |
|------|---------|-----------|
| `~/github.com`, depth 3 | 13.1 s, 15 repos | 0.010 s, 13 repos |
| `~/github.com`, depth 5 | — | 0.015 s, 15 repos |
| 200 repos + 5,000-folder non-repo tree, depth 3 | — | 0.031 s, 202 repos |
| Same + 10,000 more folders below depth 3 | — | 0.030 s (no change) |

**Behaviour matched to the current scan** (checked in the prototype):
- Folders whose names start with a dot are included. The scan sets `dotglob`, which `find` already
  matches.
- Symbolic links to folders are skipped. `find` without `-L` does not follow them, and skipping
  them also prevents loops.
- A root that is itself a repo is not listed; the scan starts one level below the root (same as
  `-mindepth 1`).
- `.git` files (worktrees, submodules) count as repos, because the check is `-e`, not `-d`.
- Unreadable folders expand to nothing (`nullglob`) and give no error.
- Folder names with spaces work, because everything is quoted and no word splitting happens.

**Alternatives considered**:
- *`find -maxdepth N -name .git -prune -print`, then strip `/.git`*: also fast (0.009 s). But
  `find` cannot stop at a repo without `-exec`, so it also searches inside repos down to the
  depth and lists nested repos within the depth. Removing those needs a second pass (sort plus
  an `awk` prefix filter), which means more code and more processes. Rejected under
  constitution V.
- *Keep `find` but add `-maxdepth`*: still starts one process per folder within the depth.
  It is cheap at depth 3 but grows with the size of each org folder. Rejected because the
  bash scan is just as simple and has no per-folder cost.
- *Skip-list of heavy folder names (`node_modules`, `target`, …)*: rejected in the spec
  assumptions. The depth limit makes it unnecessary.
- *Cache the list between runs*: rejected in the spec assumptions. A 10–30 ms scan does not
  need a cache.

## R3. Default depth

**Decision**: 3.

**Rationale**: `dev-gc` clones to `$HOME/<host>/<org>/<repo>`, so with a `~/<host>` root most
repos are at depth 2. A depth of 3 leaves one spare level for a sub-grouping folder. It finds
all 13 normal repos on the author's machine. Depth costs almost nothing (5 levels: 15 ms), so
speed is not what limits the default. The default stays at 3 to keep results predictable and
to stop the picker from showing vendored or example repos nested deep inside non-repo folders.

**Alternatives considered**: 2 (too tight for any extra grouping folder); 5 (would cover the
author's worktrees, but makes listing junk repos inside large non-repo trees more likely).
The spec already settles that deep layouts get a per-root depth instead.

## R4. Per-root depth syntax in `~/.devconfig`

**Decision**: An optional `:N` suffix on the line, for example `~/github.com:5`. If the text
after the last `:` on a line contains no `/`, it is a depth field and MUST be a whole number of
1 or more. Otherwise the line stops the picker with an error. Lines with no `:` (all lines today)
use the default.

**Rationale**:
- Spaces in paths keep working; the spec requires this. A space-separated depth would
  conflict with a folder named, for example, `Season 2`.
- It is parsed before `~`/`$VAR` expansion, so `$HOME:5` and `${HOME}/x:4` both work. The variable
  name pattern in `expand()` already stops at `:`.
- It is easy to read and familiar from `PATH`-style and `host:port` notation.
- A bad depth (for example `~/x:0` or `~/x:deep`) gives a clear error naming the file and line,
  as FR-006 requires. It is never ignored silently.

**Known limitation**: a root whose last path component contains a `:` cannot be written. On
macOS, Finder does not allow `:` in names, and such folders are very rare on Linux. Documented in
the README.

**Alternatives considered**:
- *`<path> <depth>` (whitespace-separated)*: clashes with paths containing spaces. Rejected by
  the spec.
- *Tab-separated*: the separator is invisible and easy to break in an editor. Rejected.
- *`depth=N` key/value or a separate config line*: wordier, and more parsing than the feature
  needs. Rejected under constitution V.
- *One global depth setting (env var)*: cannot raise the depth for just one root, which User
  Story 2 requires. Rejected.

## R5. Testing

**Decision**: Extend `tests/smoke.sh` (run by `tests/verify.sh mac|linux` under bash 3.2 and in
the Debian container):
- Update `scenario_dev_roots_file`: add a repo at depth 4 that is not listed by default and is
  listed with `:4`, plus a bad-depth line that fails with an error naming the line.
- Update `scenario_dev_list_200`: add a non-repo tree of at least 5,000 folders and tighten the
  limit to under 1 s (SC-002).
- New `scenario_dev_depth_cost`: list once, add 10,000 folders below the depth, list again, and
  check that the result is the same and the time is still under 1 s (SC-003 as a robust
  threshold, not a fragile ±10% timing check).

`SECONDS` is too coarse for a 1 s limit, so time with a millisecond clock. Bash 3.2 has no
`EPOCHREALTIME`, so time a block with `perl -MTime::HiRes` if it is present, or else
`date +%s%N` on Linux. The exact helper is chosen in tasks; both are stock on the targets.
