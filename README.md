# Dev-sessionizer

## Pre-requisites

- Neovim
- tmux
- fzf
- bash
- bash-completion (needed for tab completion scripts such as the one `install-locally` installs for `go-task`; on Arch: `pacman -S bash-completion`)
- git (for `task install`, which initializes the Oh My Bash submodule)

## Install

Clone this repository, then from the repo root:

```bash
git submodule update --init --recursive
task install
```

That copies Neovim, tmux, `~/.config/bin`, deploys Oh My Bash to `~/.config/oh-my-bash` (including the `dev-sessionizer` theme and custom plugins), installs **`~/.config/bash/dev-sessionizer.bash`** (the shared prompt, PATH, aliases, and Oh My Bash wiring), and copies Neovim plugins from `env/vendor/nvim/` into `~/.local/share/nvim/site/pack/vendor/start/`.

Your **`~/.bashrc` is not overwritten** after the first setup: if you do not have one yet, `env/.bashrc.example` is copied to `~/.bashrc` once. Put machine-specific settings there and keep a single line that sources `~/.config/bash/dev-sessionizer.bash`. Re-run `task install` anytime to refresh the shared file from this repo.

If your login shell is still something other than bash, new tmux panes use bash via `default-shell` in the bundled tmux config. To use bash everywhere, set your login shell to bash (e.g. `chsh -s /usr/bin/bash`).

If you previously used a monolithic `~/.bashrc` from this repo, move your local-only lines to the top of `~/.bashrc` and end the file with:

`[[ -f $HOME/.config/bash/dev-sessionizer.bash ]] && source "$HOME/.config/bash/dev-sessionizer.bash"`

## Neovim plugins

Plugins are vendored as git submodules under `env/vendor/nvim/` and installed to `~/.local/share/nvim/site/pack/vendor/start/` by `task install`. No internet access is required after the initial clone.

**To add a plugin:**

```bash
git submodule add <github-url> env/vendor/nvim/<plugin-name>
# Pin to a specific commit for reproducibility:
cd env/vendor/nvim/<plugin-name> && git checkout <commit-hash> && cd -
git add .gitmodules env/vendor/nvim/<plugin-name>
git commit -m "vendor: add <plugin-name>"
```

Then add the corresponding `require('<plugin>').setup({})` call to `env/.config/nvim/init.lua` and run `task install`.

**To update a plugin:**

```bash
cd env/vendor/nvim/<plugin-name> && git fetch && git checkout <new-commit-hash> && cd -
git add env/vendor/nvim/<plugin-name>
git commit -m "vendor: update <plugin-name> to <new-commit-hash>"
```

## Transporting to an airgapped machine

`task pack` creates `backup.tar.gz` containing the full runtime state (Mason LSP binaries, treesitter parsers, nvim state) plus the repo's `env/` directory. Plugin source is excluded from the archive since it lives in the repo itself.

```bash
# On the internet-connected machine:
task pack
# Transfer backup.tar.gz to the airgapped machine, then:
tar -xzvf backup.tar.gz
cd backup
task unpack
```

`task unpack` runs `task clean` then `task install` (sequential), then restores the runtime state from the archive.

## TODO

- [ ] Make sure to source `.bashrc` when starting the tmux-session. Or add the line above to the `.bash_profiles`-file instead
- [ ] Figure out a way to not need two keyboard-layers for writing in norwegian
