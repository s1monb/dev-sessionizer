---

description: "Task list for the bounded repo scan in the dev project picker"
---

# Tasks: Bounded Repo Scan for the Project Picker

**Input**: Design documents from `/specs/002-bounded-repo-scan/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/cli.md, quickstart.md

**Tests**: Included. The plan (research.md R5) and constitution workflow require smoke-test
coverage in `tests/smoke.sh`. Write each story's tests first and confirm they fail against the
current `find` scan before changing `env/.config/bin/dev`.

**Organization**: Tasks are grouped by user story so each story can be implemented and tested
on its own.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: The user story the task belongs to (US1, US2)

## Path Conventions

- Script under change: `env/.config/bin/dev` (deployed to `~/.config/bin/dev` by `install.sh`)
- Tests: `tests/smoke.sh`. Scenarios are auto-discovered by the `scenario_` prefix and run via
  `tests/verify.sh lint|mac|linux`.
- All shipped bash MUST run on bash 3.2 (`/bin/bash` on macOS) under `set -euo pipefail`.

---

## Phase 1: Setup

**Purpose**: Get onto the feature branch and record a baseline

- [X] T001 Create and switch to branch `002-bounded-repo-scan` from `main`. Run
  `tests/verify.sh lint` to confirm a clean baseline, and record the current
  `time ~/.config/bin/dev --list` result and `~/.config/bin/dev --list | sort` in
  `/tmp/dev-before` for the quickstart.md comparison (no repo files change)

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: A timer the smoke tests need for the under-1 s checks. `SECONDS` is too coarse.

- [X] T002 Add a `now_ms` helper to the harness section of `tests/smoke.sh`, next to the
  `assert_*` helpers. It prints the current time in milliseconds. Use `date +%s%N` when the
  output is all digits (GNU/Linux), otherwise
  `perl -MTime::HiRes=time -e 'printf "%d\n", time*1000'` (macOS). It must be bash 3.2-safe,
  with no `EPOCHREALTIME`.

**Checkpoint**: Harness can measure sub-second durations on macOS and Linux

---

## Phase 3: User Story 1 - Picker opens quickly on a real machine (Priority: P1) 🎯 MVP

**Goal**: `dev --list` searches each root at most 3 folders deep, stops at repos, and starts no
process per folder. It finishes in under 1 s with no change to existing roots files.

**Independent Test**: A root with 200 repos at depth 2 next to a non-repo tree of at least 5,000
folders lists all 200 in under 1 s. Adding 10,000 more folders below depth 3 does not change the
result and stays under 1 s.

### Tests for User Story 1 (write first, confirm they FAIL on the current scan)

- [X] T003 [US1] In `tests/smoke.sh`, extend `scenario_dev_list_200`. After creating the 200 repos,
  add a non-repo tree of at least 5,000 folders under `$HOME/r1/big` (for example
  `20 x 25 x 10` nested folders made with one `mkdir -p` per top-level folder, kept fast), and
  replace the `SECONDS` check with `now_ms`. Assert that all 200 repos are listed and that the
  run takes `-lt 1000` ms (SC-002). Keep the existing "lists all 200 repos" assertion text.
- [X] T004 [US1] In `tests/smoke.sh`, add `scenario_dev_depth_cost` after
  `scenario_dev_list_200`:
  - Make `$HOME/r/org/repo{1..20}/.git` and a non-repo folder `$HOME/r/org/data`. Write
    `~/r` to `~/.devconfig`.
  - Capture `dev --list`.
  - Add 10,000 folders strictly deeper than depth 3 under `$HOME/r/org/data/x/` (for example
    `$HOME/r/org/data/x/a$i/b$j`).
  - Assert that the list is unchanged and that the second run takes `-lt 1000` ms (SC-003).
- [X] T005 [US1] In `tests/smoke.sh`, extend `scenario_dev_roots_file` with depth-default
  coverage, keeping the existing `p/one`, `q/two` and `p/one/nested` cases:
  - Add `$HOME/p/a/b/three/.git` (depth 3, MUST be listed) and `$HOME/p/a/b/c/four/.git`
    (depth 4, MUST NOT be listed by default).
  - Add `$HOME/p/.hidden/five/.git` (hidden folders MUST still be listed).
  - Add `$HOME/p/wt/.git` as a file (`printf 'gitdir: x\n'`), which MUST be listed as a repo.
  - Add a symlink `$HOME/p/link -> $HOME/q` whose repos MUST NOT be listed through the link.
  - Update the expected sorted list accordingly (SC-004, FR-001, FR-002, FR-004).
- [X] T006 [US1] Run `tests/smoke.sh scenario_dev_list_200 scenario_dev_depth_cost scenario_dev_roots_file`
  and confirm the new assertions fail on the current `find` scan (timing and/or the depth-4
  repo being listed). Record which ones fail.

### Implementation for User Story 1

- [X] T007 [US1] In `env/.config/bin/dev`, add a `scan ROOT DEPTH` function above `list()`.
  It does a breadth-first walk in plain bash, as described in research.md R2 and
  data-model.md "Scan":
  - Local arrays `level`/`next`. Start with `level=("$root")`.
  - For each level up to `DEPTH`, glob `"$d"/*/` with `nullglob` and `dotglob` enabled. Strip
    the trailing `/` and skip `[[ -L $d ]]`.
  - If `[[ -e $d/.git ]]`, `printf '%s\n' "$d"`; otherwise append to `next`.
  - Use `level=(${next[@]+"${next[@]}"})` so empty arrays are safe under `set -u` on bash 3.2.
  - Set the `shopt` options inside the function and restore them, or only call it from the
    `--list` path, so `open_session` is unaffected.
  - Do not call `find`, `test` or any other external command.
- [X] T008 [US1] In `env/.config/bin/dev`, replace the `find "$root" … -exec test …` line in
  `list()` with `scan "$root" 3`, using a `default_depth=3` variable at the top next to
  `roots_file` (FR-002). Keep skipping missing roots with `[[ -d $root ]] || continue`.
- [X] T009 [US1] Run `tests/smoke.sh scenario_dev_list_200 scenario_dev_depth_cost scenario_dev_roots_file scenario_dev_sessions`
  under `DS_BASH=/bin/bash` and confirm that all pass.

**Checkpoint**: US1 is complete. The picker is fast, existing roots files work unchanged, and repos
deeper than 3 are hidden.

---

## Phase 4: User Story 2 - Reach deeper repos when a root needs it (Priority: P2)

**Goal**: An optional `:N` suffix on a `~/.devconfig` line sets that root's search depth. A bad
value stops the picker with a clear error.

**Independent Test**: A repo at depth 4 is hidden with `~/p`, listed with `~/p:4`, and another
root on the same file still uses depth 3. `~/p:0` and `~/p:deep` exit 1 with an error naming
`.devconfig`, the line number and the value.

### Tests for User Story 2 (write first, confirm they FAIL)

- [X] T010 [US2] In `tests/smoke.sh`, add `scenario_dev_root_depth`:
  - Make `$HOME/p/a/b/c/four/.git`, `$HOME/q/a/b/c/four/.git` and `"$HOME/My Projects/x/.git"`.
  - Write the roots file lines `~/p:4`, `~/q` and `$HOME/My Projects:1`. Assert that the sorted
    list is exactly `$HOME/My Projects/x` and `$HOME/p/a/b/c/four`, which shows the per-root
    depth, the default for other roots, and spaces in paths (US2 scenarios 1–2).
  - Add a line `~/a:b/c` with `$HOME/a:b/c/r/.git` present, and assert that `$HOME/a:b/c/r`
    is listed: the text after the last `:` contains `/`, so the colon is part of the path
    (data-model.md examples).
  - For each bad line `~/p:0`, `~/p:deep` and `~/p:` (written as the 3rd line of an otherwise
    valid file), `assert_fail dev --list` and `assert_contains` that stderr includes
    `.devconfig line 3` and the bad value. Also check that stdout is empty (US2 scenario 3,
    FR-006).
  - Reuse the `$(touch $HOME/pwned)` guard: a line `$(touch $HOME/pwned):2` MUST NOT create
    the file.
  - Picker path: put a stub `fzf` first on `PATH` (`$HOME/stub/fzf`, which runs
    `touch "$HOME/fzf-ran"; cat >/dev/null`). With the `~/p:deep` file, `assert_fail dev` (no
    arguments) and `assert_contains` that stderr includes `.devconfig line 3`. Also check that
    `$HOME/fzf-ran` does not exist, which proves the error is raised before the picker starts
    (contracts/cli.md "dev (picker)").
- [X] T011 [US2] Run `tests/smoke.sh scenario_dev_root_depth` and confirm that it fails before
  implementation.

### Implementation for User Story 2

- [X] T012 [US2] In `list()` in `env/.config/bin/dev`, track a line number `n` and, for each
  non-blank, non-comment line, split off the depth *before* calling `expand`, as specified in
  data-model.md:
  - If the line matches `^(.*):([^/]*)$`, the path is `BASH_REMATCH[1]` and the depth text is
    `BASH_REMATCH[2]`.
  - The depth text MUST match `^[1-9][0-9]*$` ("a whole number of 1 or more"). Otherwise run
    `die "$roots_file line $n: bad depth '$value' (want a whole number of 1 or more)"`.
  - If there is no match, the depth is `$default_depth`.
  - Then `root="$(expand "$path")"`, `[[ -d $root ]] || continue`, and `scan "$root" "$depth"`.
- [X] T013 [US2] Split T012's loop in `env/.config/bin/dev` into two steps so every line is
  checked in the main shell before any scanning or `fzf` starts:
  - `read_roots`: calls `need_roots`, then fills the global arrays `roots=()` and `depths=()`.
    It dies on a bad depth and skips roots that do not exist.
  - `scan_roots`: loops over the arrays and calls `scan "${roots[i]}" "${depths[i]}"`.
  - `--list` runs `read_roots; scan_roots`.
  - The picker runs `read_roots` *outside* the pipe, then `target="$(scan_roots | fzf)" || exit 0`.

  This way a bad depth gives no stdout, and the picker exits 1 with the error instead of showing an
  empty `fzf` screen. Keep it bash 3.2-safe: use a `while read` loop (no `mapfile`/`readarray`)
  and `${roots[@]+…}` guards under `set -u`.
- [X] T014 [US2] Update `need_roots()` in `env/.config/bin/dev` so the missing-file message
  matches contracts/cli.md:
  `create it with one project root per line, e.g. ~/github.com (add :N to search N folders deep, default 3)`.
  Update the header usage comment at the top of the script to mention `:N` (FR-009).
- [X] T015 [US2] Run `tests/smoke.sh scenario_dev_root_depth scenario_dev_roots_file` under
  `DS_BASH=/bin/bash` and confirm that both pass. The existing "error names the roots file"
  assertion MUST still pass.

**Checkpoint**: US1 and US2 both work. Deep roots can be opted in per line.

---

## Phase 5: Polish & Cross-Cutting Concerns

- [X] T016 [P] Update the "Project sessions" paragraph in `README.md` to document:
  - the default search depth of 3 folders below each root;
  - the `:N` suffix, with the example `~/github.com/s1monb/worktrees:3`;
  - that `dev PATH` opens any folder regardless of depth;
  - the known limitation that the last folder in a root path cannot contain `:` (FR-003,
    FR-009, constitution workflow rule);
  - that comments must be on their own line.
- [X] T017 [P] Update the `dev --list` and `dev [PATH]` sections of
  `specs/001-baseline-existing-toolkit/contracts/cli.md` to point to
  `specs/002-bounded-repo-scan/contracts/cli.md` for the roots-file depth and new error.
- [X] T018 Run `tests/verify.sh lint` (bash -n, shellcheck, portability gates) and fix any
  findings in `env/.config/bin/dev` and `tests/smoke.sh`.
- [X] T019 Run `tests/verify.sh mac` and `tests/verify.sh linux`; all scenarios MUST pass
  (constitution I: both platforms).
- [X] T020 Run the manual steps in `specs/002-bounded-repo-scan/quickstart.md` on the real
  machine after `./install.sh`:
  - `time dev --list` is under 1 s (SC-001);
  - `comm -23 /tmp/dev-before <(dev --list | sort)` shows only the two
    `s1monb/worktrees/perceptiq/*/perceptiq` checkouts (SC-004);
  - adding `~/github.com/s1monb/worktrees:3` brings them back (SC-005);
  - a bad depth errors.

  Leave `~/.devconfig` as the user wants it.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (T001)** → **Foundational (T002)** → **US1 (T003–T009)** → **US2 (T010–T015)** →
  **Polish (T016–T020)**
- US2 depends on US1: it adds parsing around the `scan` function and the `default_depth`
  variable from T007–T008. Both stories edit `env/.config/bin/dev` and `tests/smoke.sh`, so
  they run one after the other.

### Within Each User Story

- Tests come first and must fail (T003–T006, T010–T011), then implementation, then a green run.
- T007 before T008 (T008 calls `scan`). T012 before T013 (T013 restructures T012's loop).

### Parallel Opportunities

- T003, T004 and T005 all edit `tests/smoke.sh`. They are independent scenarios, but they share a
  file, so they are not marked [P]. Do them in one pass.
- T016 (`README.md`) and T017 (`specs/001…/contracts/cli.md`) can run in parallel with each
  other, and with T018 once the code is final.

---

## Parallel Example: Polish

```bash
Task: "Update README.md Project sessions paragraph for :N depth (T016)"
Task: "Point 001 contracts/cli.md dev sections at the 002 contract (T017)"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. T001–T002
2. T003–T009. The picker goes from about 13 s to well under 1 s, and no roots file needs to change.
3. **STOP and VALIDATE**: `time dev --list` on the real machine. The two worktree checkouts are
   hidden until US2 is done.

### Incremental Delivery

1. MVP (US1). It can be committed as `fix: bound dev repo scan depth`.
2. US2 adds `:N` per-root depth and errors (`feat: per-root search depth in ~/.devconfig`).
3. Polish: README, the 001 contract pointer, and lint and both platforms green before merge.

---

## Notes

- Do not add skip-lists, caching or new tools (constitution V; spec assumptions).
- Nothing from `~/.devconfig` may be evaluated. The only expansion is through the existing
  `expand()`, and the depth is split off before it runs.
- Commit after each phase with a conventional prefix.
