# Contract: `sandbox` changes

Extends [003 contracts/cli.md](../../003-agent-sandbox/contracts/cli.md). Synopsis and options
are unchanged.

## Mode selection

1. A mode on the command line (`claude`, `opencode`, `shell`) wins.
2. Otherwise `SANDBOX_AGENT` from `~/.config/local/sandbox.env` (rules in data-model.md).
3. Otherwise `claude`.

`--help` names `SANDBOX_AGENT` in the help text.

## New exit-1 cases (message on stderr prefixed `sandbox:`, nothing started)

| Case | Checked |
|------|---------|
| Unsupported `SANDBOX_AGENT` while no mode is given | before any Docker call |
| Packed image built for other ids | after `docker info`, before volume and run |
| `--rebuild` with a packed image | same |

## New notice (stderr, session still starts)

- Packed image whose `dev-sessionizer.files` differs from the installed files.

## Image handling

As in data-model.md "Decision table". `sandbox` never runs `docker build` or `docker pull` for a
packed image.

## Inside the container (entrypoint)

| Setting | When |
|---------|------|
| `OPENCODE_DISABLE_AUTOUPDATE=1` | always (image `ENV`) |
| `OPENCODE_DISABLE_MODELS_FETCH=1`, `OPENCODE_DISABLE_LSP_DOWNLOAD=1` | `SANDBOX_OFFLINE=1` |
| `"skipDangerousModePermissionPrompt": true` merged into `~/.claude/settings.json` (container copy) | always, after copying host config |

`SANDBOX_AGENT` reaches the container through `--env-file` like every other line of
`sandbox.env`. It has no effect there.
