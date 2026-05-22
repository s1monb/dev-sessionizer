# Neovim plugins vendored as git submodules, loaded via traditional pack dirs

Neovim plugins are vendored as git submodules under `env/vendor/nvim/<plugin-name>/` and installed to `~/.local/share/nvim/site/pack/vendor/start/` by `task install`. This replaces `vim.pack.add()` (which downloads from GitHub at runtime).

## Considered Options

**Pack-carries-plugins**: run nvim once on an internet machine, let `vim.pack.add()` download plugins to `~/.local/share/nvim/`, then include that directory in `task pack`. Simpler, but relies on an internet-connected first run before packing, and the tarball silently carries stale plugin state if the nvim share dir isn't fresh.

**Git submodules (chosen)**: plugins are auditable in the repo tree, version-pinned via submodule commit (instead of a `version =` field in `init.lua`), and placed by `task install` — no internet needed at any point after the initial clone. The `task pack` tarball excludes `site/pack/vendor/` since `task unpack` re-runs `task install` anyway.

## Consequences

Every new plugin requires a `git submodule add` under `env/vendor/nvim/` and a corresponding `require` in `init.lua`. Plugin dependencies must also be submoduled explicitly — there is no transitive resolution.
