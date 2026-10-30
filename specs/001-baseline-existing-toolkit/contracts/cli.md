# CLI Contracts

Every command writes progress to stdout and errors to stderr. Exit code 0 means success; any
non-zero code means failure, with a one-line reason.

## Repo entry points

### `./install.sh`

Installs or updates every component from the folder that contains the script (a repo checkout
or an extracted archive).

| Case | Exit | Behaviour |
|------|------|-----------|
| All pre-requisites present | 0 | Replaces managed paths, creates missing override stubs, generates optional completions |
| Hard pre-requisite(s) missing or too old | 1 | Prints `missing: a, b, …` and/or `outdated: nvim 0.10.4 (need ≥ 0.12)` and exits **before any write** |
| A vendored folder is empty | 1 | In a git checkout, prints `run: git submodule update --init --recursive`; in an extracted archive, prints `incomplete archive: env/vendor/<name> missing`. Exits before any write |
| Optional tool missing | 0 | That tool's extras are skipped silently |

It takes no arguments and is idempotent.

### `./pack.sh [OUTPUT]`

- `OUTPUT` defaults to `./dev-sessionizer.tar.gz`.
- It writes exactly that one file, with the layout described in
  [data-model.md](../data-model.md#archive).
- Exit 0 whether or not runtime state exists. Leaves no temporary files behind.
- Exit 1 if `OUTPUT`'s folder is not writable.

### `./unpack.sh` (run from inside the extracted `dev-sessionizer/` folder)

| Case | Exit | Behaviour |
|------|------|-----------|
| `MANIFEST` os/arch match | 0 | Runs `install.sh`, then **replaces** existing runtime state (everything under `~/.local/share/nvim` except `site/`, and `~/.local/state/nvim`) with the archive's |
| os/arch mismatch | 0 | Runs `install.sh`, warns `runtime state from <os>/<arch> skipped on <os>/<arch>` |
| Install fails | same as install | Runtime state is not touched |

It never opens a network connection and never writes to override files.

**Documented unpack**: `tar -xzf dev-sessionizer.tar.gz && ./dev-sessionizer/unpack.sh`

### `tests/verify.sh [lint|mac|linux|all]`

- The default is `all`, which runs `lint`, then `linux`, then `mac` (when on macOS).
- It prints one `PASS`/`FAIL <target>: <reason>` line per target, and exits 1 if any target
  fails.
- It never touches the real `$HOME`, and refuses to run if the sandbox home resolves to it.

## Installed commands (`~/.config/bin`)

### `dev [PATH]`

- With `PATH`, it opens or switches to a session for that folder. Without it, it fuzzy-picks
  from the git repos under the roots in `~/.devconfig`.
- **Session name**: the basename sanitised to `[A-Za-z0-9_-]`. If that name is already used by a
  session for a different path, `_<parent>` is appended.
- **Exit codes**:
  - 0: the session was opened or switched to, or the user cancelled the picker.
  - 1: `~/.devconfig`, `fzf` or `tmux` is missing. The message names the missing item and the
    fix.
- **Keybinding**: Ctrl-F in an interactive shell (unchanged).
- **`dev --list`**: prints every repo found under the roots, one per line, and exits 0. Exits 1 if
  `~/.devconfig` is missing. The picker reads its candidates from this list; tests use it directly.
  The search depth per root (`:N`, default 3) and the bad-depth error are defined in
  `specs/002-bounded-repo-scan/contracts/cli.md`.
- **`DS_DEV_NO_ATTACH=1`**: creates or reuses the session but does not attach or switch to it. Used
  by the smoke tests, which have no terminal.

### `dev-gc <git-url>`

The behaviour is unchanged. It accepts `git@host:path.git` and `http(s)://host/path.git`, and
clones into `~/<host>/<path>`. If the destination already exists, it asks for a new name; an
empty answer aborts with exit 1.

### `esc-caps-swap`

- Toggles the GNOME `caps:swapescape` setting.
- If `gsettings` is missing or the desktop is not GNOME, it prints
  `esc-caps-swap: requires GNOME (gsettings)` and exits 1.
