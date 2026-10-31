# Dev-sessionizer

A portable bash, tmux and Neovim environment for macOS and Linux. One command installs or updates
it, and a single archive carries it to airgapped machines.

## Pre-requisites

**Hard** (install checks these and stops, listing everything missing, before changing anything):

- bash, git, fzf, tar, find
- tmux ≥ 3.2
- Neovim ≥ 0.12 (the vendored blink.cmp needs it)

**Optional** (extras are skipped when absent):

- `xsel` (X11) or `wl-copy` (Wayland): tmux copy to the clipboard on Linux
- `direnv`, `jq` (used by `jwt-decode`)
- `flux`, `talosctl`: their bash completions are generated at install time
- `gsettings` on GNOME: needed by `esc-caps-swap`
- the `bash-completion` package (on Arch: `pacman -S bash-completion`)
- Docker: for `sandbox` (it also needs network to build its image) and for `tests/verify.sh`

## Install and update

```bash
git clone --recursive <repo-url>
cd dev-sessionizer
./install.sh
```

Run `./install.sh` again at any time to update. It replaces the paths it owns and nothing else:

- `~/.config/{bash/dev-sessionizer.bash,bash/completions,oh-my-bash,tmux,nvim,bin,k9s}`
- `~/.local/share/nvim/site/pack/vendor/start` (the vendored Neovim plugins)

Install needs no network access: everything third-party is vendored under `env/vendor/`. If you
cloned without `--recursive`, install tells you to run `git submodule update --init --recursive`.

New tmux panes start the `bash` on your PATH. To use bash everywhere, make it your login shell, for
example `chsh -s "$(command -v bash)"` (on macOS, add the Homebrew bash to `/etc/shells` first).

## Machine-local overrides

Install creates these once if they are missing and never touches them again. Each one loads after
the shared defaults, so its settings win.

| Component | Override |
|-----------|----------|
| Shell, prompt, aliases | `~/.bashrc` (sources the shared setup first, then your lines) |
| Neovim | `~/.config/local/nvim.lua` |
| tmux | `~/.config/local/tmux.conf` |
| Personal scripts | `~/.config/local/bin/` (first on PATH) |
| Agent sandbox environment | `~/.config/local/sandbox.env` (mode 600) |

Don't edit the installed copies under `~/.config/nvim`, `~/.config/tmux` and so on: the next install
replaces them.

If you previously used a monolithic `~/.bashrc` from this repo, keep only your machine-specific
lines and put this line before them:

```bash
[[ -f $HOME/.config/bash/dev-sessionizer.bash ]] && source "$HOME/.config/bash/dev-sessionizer.bash"
```

## Project sessions

`dev` (or Ctrl-F in the shell) fuzzy-picks a git repository under the folders listed in
`~/.devconfig` and opens a tmux session for it, or switches to the existing one. `~/.devconfig`
holds one folder per line; `~` and `$VAR` are allowed, and lines starting with `#` are comments
(a `#` later in a line is part of the path).

Each folder is searched 3 levels deep by default. End a line with `:N` to search that folder `N`
levels deep instead:

```text
~/github.com
~/github.com/s1monb/worktrees:3
```

`dev PATH` opens any folder, however deep. The last folder in a root's path cannot contain `:`,
because the text after it is read as a depth.

## Agent sandbox

`sandbox` runs a coding agent with its permission prompts turned off, inside a throwaway Docker
container that can only write to one project folder:

```bash
sandbox                      # Claude Code in the current folder
sandbox opencode ~/proj      # OpenCode in ~/proj
sandbox shell                # bash in the same environment, for debugging
sandbox -- --resume          # everything after -- goes to the agent (or to bash for shell)
sandbox --rebuild            # rebuild the image, e.g. for newer agent versions
sandbox --reset              # empty this project's tool cache first
sandbox --network host       # another docker network for this run
```

The image is built on first use and rebuilt automatically when its files change. Each session gets
a new container that is removed when the agent exits.

**Logging in.** Your Claude Code and OpenCode config (`~/.claude`, `~/.claude.json`,
`~/.config/opencode`, OpenCode's `auth.json`) is mounted read-only and copied into the container,
so the agent has your settings, `CLAUDE.md`, agents and MCP servers. It can change its copy but not
yours. Session history is not copied. Claude Code's own login is not carried over (on macOS it is in
the Keychain), so create a long-lived token with `claude setup-token` and put it in
`~/.config/local/sandbox.env`:

```text
CLAUDE_CODE_OAUTH_TOKEN=...
```

That file is passed to Docker as `--env-file` (one `KEY=value` per line, no quotes) and is the
place for any other variable the sandbox needs. `CLAUDE_CODE_OAUTH_TOKEN` and `ANTHROPIC_API_KEY`
from your shell are passed too, as are your git name and email.

**Toolchains.** If the project has `mise.toml`, `.mise.toml` or `.tool-versions`, the tools are
installed before the agent starts. Installed tools and package caches live in a Docker volume per
project, so the next start is fast. The agent has no root and cannot `apt install`; tools come from
mise.

**What is isolated:** the agent runs as your user ID with no capabilities, no sudo and no way to
gain privileges. It cannot write anywhere on the host except the project folder. It gets no SSH
keys or agent, git credentials, GitHub token, cloud credentials or Docker socket, so it can commit
but not push. Nothing is exposed on host ports.

**What is not:**

- It has full internet access.
- It can change anything in the project, including `.git`. Git hooks and git config run on the
  host the next time you use git there, and they do not show up in a diff. Review what the agent
  changed (scripts, `package.json`, `.envrc`, and `.git/hooks`, `.git/config`) before running
  anything in the project on the host.
- A remote URL with an embedded token lets it push.
- OpenCode providers that log in with OAuth may refresh their token inside the sandbox and log out
  the host copy. API-key providers are unaffected.
- Git worktrees do not work inside, because their `.git` points outside the project. Config files
  that are symlinks to elsewhere (e.g. a dotfiles repo) arrive broken.

On a Linux machine where containers on the default bridge network have no internet, set
`export SANDBOX_NETWORK=host` in `~/.bashrc`. The sandbox needs network, so it does not work on an
airgapped machine.

## Transporting to an airgapped machine

```bash
# On the connected machine:
./pack.sh                       # writes dev-sessionizer.tar.gz

# Copy the archive over, then on the airgapped machine:
tar -xzf dev-sessionizer.tar.gz && ./dev-sessionizer/unpack.sh
```

The archive holds the installable tree, its own `unpack.sh`, and the Neovim runtime state (Mason
language servers, treesitter parsers, editor state). Unpack runs install, then replaces the target's
runtime state with the archive's. Runtime state is native code, so it is only restored when the
archive was made on the same OS and CPU architecture; otherwise unpack says so and skips it. Your
override files are never touched.

## Neovim keymaps

[which-key](https://github.com/folke/which-key.nvim) shows the available keys in a popup when you
pause after a prefix, such as `<Space>` (the leader), `g` or `ys`. `<Space>kk` lists every keymap
and `<Space>?` lists the ones local to the current buffer. When you add a keymap in
`env/.config/nvim/lua/config/keymaps.lua`, give it a description (the last argument of `map`) so
the popup can name it. The smoke test checks that every leader keymap has one.

## Neovim plugins

Plugins are vendored as git submodules under `env/vendor/nvim/` and installed by `./install.sh`.

**To add a plugin:**

```bash
git submodule add <github-url> env/vendor/nvim/<plugin-name>
# Pin to a specific commit for reproducibility:
cd env/vendor/nvim/<plugin-name> && git checkout <commit-hash> && cd -
git add .gitmodules env/vendor/nvim/<plugin-name>
git commit -m "vendor: add <plugin-name>"
```

Then add the corresponding `require('<plugin>').setup({})` call to `env/.config/nvim/init.lua` and
run `./install.sh`.

**To update a plugin:**

```bash
cd env/vendor/nvim/<plugin-name> && git fetch && git checkout <new-commit-hash> && cd -
git add env/vendor/nvim/<plugin-name>
git commit -m "vendor: update <plugin-name> to <new-commit-hash>"
```

## Verifying changes

```bash
tests/verify.sh          # lint + linux + mac
tests/verify.sh lint     # bash -n, shellcheck, portability and network checks
tests/verify.sh linux    # smoke test in a Debian container, plus unpack without network
tests/verify.sh mac      # smoke test on macOS with the entry scripts under /bin/bash (3.2)
tests/verify.sh sandbox  # agent sandbox checks against your Docker (needs network; not in the default)
```

Every test runs against a throwaway `$HOME`; your real home is never touched. CI runs the same
targets on Ubuntu and macOS.

## TODO

- [ ] Figure out a way to not need two keyboard-layers for writing in norwegian
