# Implementation Plan: Bounded Repo Scan for the Project Picker

**Branch**: `002-bounded-repo-scan` | **Date**: 2026-10-31 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/002-bounded-repo-scan/spec.md`

## Summary

`dev --list` takes about 13 s on a real machine for two reasons. It searches every non-repo
folder with no depth limit, and it starts a `test` process for each folder visited. The plan
replaces the `find … -exec test` scan in `env/.config/bin/dev` with a short breadth-first
scan in plain bash. The scan stops at each repo, starts no processes, and ends at a per-root
depth (default 3, override with `~/github.com:5` in `~/.devconfig`). A prototype lists the
author's 15 repos in 15 ms at depth 5, and 200 repos next to a 15,000-folder non-repo tree in
30 ms. See [research.md](research.md).

## Technical Context

**Language/Version**: bash; MUST run on 3.2 (stock macOS `/bin/bash`) and current Linux bash

**Primary Dependencies**: none new. The scan uses only bash built-ins; `tmux` and `fzf` are
unchanged

**Storage**: N/A (reads the user-owned `~/.devconfig`)

**Testing**: `tests/smoke.sh` scenarios via `tests/verify.sh lint|mac|linux`

**Target Platform**: macOS and Linux

**Project Type**: CLI script in a dotfiles/toolkit repo

**Performance Goals**: `dev --list` under 1 s for 200 repos plus 5,000 non-repo folders. Time
does not depend on the number of folders below the depth

**Constraints**: no new tools; roots files written for today's version stay valid; nothing in
the roots file is ever run

**Scale/Scope**: one script (`env/.config/bin/dev`, about 30 lines changed), smoke tests, and one
README paragraph

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Portable across macOS and Linux | PASS | Bash built-ins only. Removes the dependence on `find` flag behaviour. Verified under `/bin/bash` 3.2; Linux checked by `verify.sh linux`. |
| II. One-command install and update | PASS | No install change; `install.sh` already deploys `env/.config/bin/dev`. |
| III. Transferable via files | PASS | No new dependencies, nothing to vendor or pack. |
| IV. Overwriteable by design | PASS | `~/.devconfig` stays user-owned and is never written. Old roots files keep working unchanged. |
| V. Minimal and simple | PASS | Replaces one `find` line with a ~15-line function; no skip-lists, no cache, no new language. |
| Workflow: README in same change | PASS (planned) | Roots-file depth syntax is added to README "Project sessions" (FR-009). |

**Post-design re-check**: still PASS. The design adds one optional suffix to the roots-file
format and one function. No violations, so Complexity Tracking is empty.

## Project Structure

### Documentation (this feature)

```text
specs/002-bounded-repo-scan/
├── spec.md
├── plan.md              # this file
├── research.md          # R1–R5: cause, scan method, default depth, syntax, testing
├── data-model.md        # roots-file entry and scan rules
├── quickstart.md        # automated and manual validation
├── contracts/cli.md     # dev / dev --list / ~/.devconfig changes vs 001
├── checklists/requirements.md
└── tasks.md             # /speckit-tasks (not yet created)
```

### Source Code (repository root)

```text
env/.config/bin/dev      # parse ":N" per root, replace find with a bounded bash scan,
                         # update the missing-roots-file message
tests/smoke.sh           # update scenario_dev_roots_file and scenario_dev_list_200;
                         # add scenario_dev_depth_cost and a millisecond timer helper
README.md                # "Project sessions": document :N and the default depth 3
```

**Structure Decision**: Change the existing files in place. No new files outside `specs/`.

## Complexity Tracking

No violations.
