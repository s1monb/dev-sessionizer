# Dev-sessionizer

A portable, versioned developer environment for bash, tmux, and Neovim — designed to be installed on any machine and transported to airgapped environments via a single tarball.

## Language

**Vendor**:
A third-party dependency bundled directly in the repo under `env/vendor/` so it is available without network access.
_Avoid_: dependency, package, library (when referring to things under env/vendor/)

**Install**:
The act of copying environment files from the repo into `$HOME/.config/` (and related locations) on the current machine. Triggered by `./install.sh`, which also performs updates.
_Avoid_: deploy, setup, bootstrap

**Pack**:
The act of archiving the environment — the installable tree plus runtime state — into a tarball (`dev-sessionizer.tar.gz`) for transport. Triggered by `./pack.sh`.
_Avoid_: export, bundle, zip

**Unpack**:
The act of restoring a packed environment on a target machine: `unpack.sh`, run inside the extracted archive, runs install and then restores runtime state when the archive's platform matches.
_Avoid_: import, restore, extract

**Override**:
A user-owned file under `~/.config/local/` or `~/.bashrc`, created once by install and never written by it again. Loaded after the shared defaults, so it takes precedence.
_Avoid_: customisation file, local config

**Airgapped environment**:
A machine with no outbound internet access whatsoever. The pack/unpack workflow is the only transport mechanism.
_Avoid_: offline, isolated, restricted

**Runtime state**:
Files written by tools at runtime that are not part of the repo — e.g. treesitter parsers, Mason LSP binaries, nvim data. Carried by pack; restored by unpack.
_Avoid_: cache (too narrow — state includes non-cache artefacts)

**Plugin**:
A Neovim extension. Plugins are vendored as git submodules under `env/vendor/nvim/` and installed to the Neovim package directory by `./install.sh`.
_Avoid_: package (conflicts with Neovim's own "pack" terminology)

**Agent sandbox**:
A throwaway container started by `sandbox` in which a coding agent runs without permission prompts and can write only to one project folder.
_Avoid_: sandbox (alone), which in tests means the throwaway `$HOME` used by smoke scenarios
