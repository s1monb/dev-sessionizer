# Data Model: Bounded Repo Scan

Nothing is stored. The only data is the user's roots file and the in-memory scan.

## Roots file (`~/.devconfig`)

A plain text file the user owns. The repo never writes it (constitution IV).

| Line kind | Form | Handling |
|-----------|------|----------|
| Blank | empty | skipped |
| Comment | starts with `#` | skipped (a `#` later in a line is part of the path) |
| Root entry | `<path>` or `<path>:<depth>` | parsed as below |

## Root entry

| Field | Source | Rules |
|-------|--------|-------|
| `path` | Line text before the depth suffix | A leading `~` and `$VAR` / `${VAR}` are expanded, and nothing else (keeps 001 FR-022). Unset variables expand to empty. If the result is not an existing folder, the entry is skipped silently. |
| `depth` | Text after the last `:`, if that text has no `/` | A whole number of 1 or more. If absent, it is 3. Any other value is an error (see below). |

**Parsing order**: split off the depth, then expand the path. A `:` inside a variable name
cannot happen, because names are `[A-Za-z_][A-Za-z0-9_]*`.

**Examples**

| Line | path | depth |
|------|------|-------|
| `~/github.com` | `$HOME/github.com` | 3 |
| `~/github.com:5` | `$HOME/github.com` | 5 |
| `$HOME/My Projects:2` | `$HOME/My Projects` | 2 |
| `~/a:b/c` | `$HOME/a:b/c` | 3 (the text after the last `:` contains `/`, so it is part of the path) |
| `~/x:0` | — | error |
| `~/x:deep` | — | error |

**Error**: `dev: ~/.devconfig line <n>: bad depth '<value>' (want a whole number of 1 or more)`.
Exit 1, no output on stdout. Nothing from the line is run or expanded.

## Scan (per root entry)

- Level 0 is the root. Each level reads the folders inside the previous level's folders.
  Folders whose names start with a dot are included; symbolic links are skipped.
- At each level, a folder that contains a `.git` entry (file or folder) is a **repo**: it is
  printed and never opened. Every other folder moves on to the next level.
- The scan stops after level `depth`, or earlier if no folders are left.
- A repo is printed as the expanded root path joined with the folder names below it. The
  output is therefore absolute when the root is absolute.
