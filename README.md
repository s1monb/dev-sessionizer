# Dev-sessionizer

## Pre-requisites

- Neovim
- tmux
- fzf
- bash
- bash-completion (needed for tab completion scripts such as the one `install-locally` installs for `go-task`; on Arch: `pacman -S bash-completion`)
- git (for `task install-locally`, which initializes the Oh My Bash submodule)

## Install

Clone this repository, then from the repo root:

```bash
git submodule update --init --recursive
task install-locally
```

That copies Neovim, tmux, `~/.config/bin`, deploys Oh My Bash to `~/.config/oh-my-bash` (including the `dev-sessionizer` theme and custom plugins), and installs **`~/.config/bash/dev-sessionizer.bash`** (the shared prompt, PATH, aliases, and Oh My Bash wiring).

Your **`~/.bashrc` is not overwritten** after the first setup: if you do not have one yet, `env/.bashrc.example` is copied to `~/.bashrc` once. Put machine-specific settings there and keep a single line that sources `~/.config/bash/dev-sessionizer.bash`. Re-run `task install-locally` anytime to refresh the shared file from this repo.

If your login shell is still something other than bash, new tmux panes use bash via `default-shell` in the bundled tmux config. To use bash everywhere, set your login shell to bash (e.g. `chsh -s /usr/bin/bash`).

If you previously used a monolithic `~/.bashrc` from this repo, move your local-only lines to the top of `~/.bashrc` and end the file with:

`[[ -f $HOME/.config/bash/dev-sessionizer.bash ]] && source "$HOME/.config/bash/dev-sessionizer.bash"`
