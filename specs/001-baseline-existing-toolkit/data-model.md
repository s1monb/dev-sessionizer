# Data Model: Baseline the Existing Toolkit

There is no database. The "entities" are files and folders with an owner and a lifecycle.

## Component

One installable unit, defined by a source in the repo and a destination on the machine.

| Component | Repo source | Managed destination | Override (user-owned) |
|-----------|-------------|---------------------|-----------------------|
| Shell setup | `env/.config/bash/dev-sessionizer.bash` | `~/.config/bash/dev-sessionizer.bash` | `~/.bashrc` |
| Prompt / OMB | `env/vendor/oh-my-bash` + `env/.config/oh-my-bash/custom` | `~/.config/oh-my-bash` | `~/.bashrc` |
| Completions | generated at install time | `~/.config/bash/completions/` | — |
| tmux | `env/.config/tmux` | `~/.config/tmux` | `~/.config/local/tmux.conf` |
| Neovim config | `env/.config/nvim` | `~/.config/nvim` | `~/.config/local/nvim.lua` |
| Neovim plugins | `env/vendor/nvim/*` | `~/.local/share/nvim/site/pack/vendor/start/` | — |
| Scripts | `env/.config/bin` | `~/.config/bin` | `~/.config/local/bin/` |
| k9s | `env/.config/k9s` | `~/.config/k9s` | — |

**Rules**

- Install replaces each managed destination wholesale (it removes it, then copies), so it is
  idempotent.
- The list of managed destinations is defined once, in `lib.sh`. Install never deletes anything
  outside that list.

## Override file

- **Location**: `~/.bashrc`, or anything under `~/.config/local/`.
- **Lifecycle**: absent → *created once as a stub* by install → *user-owned forever*. Install,
  pack and unpack never write to it again.
- **Load order**: always after the shared defaults of its component.
- **Not packed**: overrides never travel in the archive.

## Vendored dependency

- **Fields**: path under `env/vendor/`, upstream URL, pinned commit (a submodule gitlink).
- **Validation**: install fails if the folder is missing or empty, and prints the submodule
  command.

## Runtime state

- **Sources**: `~/.local/share/nvim` (excluding `site/pack/vendor`) and `~/.local/state/nvim`.
- **Platform-bound**: valid only on the same `os` and `arch` as `MANIFEST`.

## Archive

```text
dev-sessionizer.tar.gz
└── dev-sessionizer/
    ├── MANIFEST              # os=, arch=, created=
    ├── install.sh  unpack.sh  lib.sh  README.md
    ├── env/                  # installable tree incl. env/vendor (no .git)
    └── runtime/              # optional
        ├── share/nvim/
        └── state/nvim/
```

**Lifecycle**: created by `pack.sh` → copied by hand → extracted with `tar -xzf` → `unpack.sh`
(runs install, then restores runtime state if the platform matches) → may be deleted.

## Roots file

- **Location**: `~/.devconfig`, user-owned and never installed.
- **Format**: one folder per line. `#` comments and blank lines are ignored. Allowed expansions:
  a leading `~`, plus `$VAR` and `${VAR}`. Nothing else is evaluated.
- **Validation**: folders that don't exist are skipped silently.
