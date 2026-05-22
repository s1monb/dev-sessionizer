# Dev-sessionizer

A portable, versioned developer environment for bash, tmux, and Neovim — designed to be installed on any machine and transported to airgapped environments via a single tarball.

## Language

**Vendor**:
A third-party dependency bundled directly in the repo under `env/vendor/` so it is available without network access.
_Avoid_: dependency, package, library (when referring to things under env/vendor/)

**Install**:
The act of copying environment files from the repo into `$HOME/.config/` (and related locations) on the current machine. Triggered by `task install-locally`.
_Avoid_: deploy, setup, bootstrap

**Pack**:
The act of archiving the installed environment — including runtime state — into a tarball (`backup.tar.gz`) for transport.
_Avoid_: export, bundle, zip

**Unpack**:
The act of restoring a packed environment on a target machine by running `install-locally` and restoring runtime state from the tarball.
_Avoid_: import, restore, extract

**Airgapped environment**:
A machine with no outbound internet access whatsoever. The pack/unpack workflow is the only transport mechanism.
_Avoid_: offline, isolated, restricted

**Runtime state**:
Files written by tools at runtime that are not part of the repo — e.g. treesitter parsers, Mason LSP binaries, nvim data. Carried by pack; restored by unpack.
_Avoid_: cache (too narrow — state includes non-cache artefacts)

**Plugin**:
A Neovim extension. Plugins are vendored as git submodules under `env/vendor/nvim/` and installed to the Neovim package directory by `install-locally`.
_Avoid_: package (conflicts with Neovim's own "pack" terminology)
