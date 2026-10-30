# Contract: `dev` (changes from 001)

This contract replaces the `dev [PATH]` and `dev --list` sections of
`specs/001-baseline-existing-toolkit/contracts/cli.md` where they differ. Anything not listed
here is unchanged.

## `~/.devconfig`

```text
# one root per line; blank lines and lines starting with # are ignored
# searched 3 folders deep (default)
~/github.com
# searched 4 folders deep
~/github.com/s1monb/worktrees:4
$HOME/My Projects:2
```

- Comments MUST be on their own line. A `#` later in a line is part of the path, because folder
  names may contain `#`.
- `~` and `$VAR` / `${VAR}` are expanded. Nothing else is evaluated.
- An optional `:N` at the end sets how many folders deep to search under that root
  (N ≥ 1, default 3). See `data-model.md` for parsing rules.
- Roots that do not exist are skipped.

## `dev --list`

- **stdout**: one absolute repo path per line. A repo is a folder within the root's depth that
  contains `.git`. Folders inside a repo are not searched. Order: root by root in file order,
  shallower repos before deeper ones, sorted by name within each level.
- **Exit 0**: the roots file was read; the list may be empty.
- **Exit 1**, message on stderr:
  - `~/.devconfig` is missing. The message names the file and shows an example line with a
    depth, for example
    `dev: ~/.devconfig not found; create it with one project root per line, e.g. ~/github.com (add :N to search N folders deep, default 3)`.
  - A line has a bad depth. The message names the file, the line number and the value (see
    `data-model.md`).

## `dev` (picker) and `dev PATH`

- The picker shows the output of `dev --list`. Its errors (exit 1) are the same. The roots file
  is read and checked in full *before* `fzf` starts, so a bad depth fails with the error on
  stderr and no picker is shown.
- `dev PATH` does not read the roots file, so a repo deeper than any root's depth can still be
  opened directly.

## Performance

- `dev --list` finishes in under 1 s for 200 repos plus a non-repo tree of 5,000 folders.
- Its run time does not depend on how many folders lie below each root's depth.
