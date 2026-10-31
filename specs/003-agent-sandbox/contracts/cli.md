# Contract: `sandbox`

## Synopsis

```text
sandbox [--network MODE] [--rebuild] [--reset] [claude|opencode|shell] [DIR] [-- ARGS...]
```

| Part | Meaning |
|------|---------|
| `claude` | Default. Runs `claude --dangerously-skip-permissions ARGS...` |
| `opencode` | Runs `opencode --auto ARGS...` |
| `shell` | Runs `bash ARGS...` (e.g. `sandbox shell -- -c 'id'`) |
| `DIR` | Project folder, default `.`. Validation: data-model.md |
| `--network MODE` | Passed to `docker run --network`. Default `$SANDBOX_NETWORK`, else `bridge` |
| `--rebuild` | Build the image again with `--pull --no-cache` before starting |
| `--reset` | Remove this project's tool cache before starting |
| `-h`, `--help` | Usage on stdout, exit 0 |

Options may come before or after the mode and `DIR`. Everything after `--` goes to the agent or
shell unchanged.

## Exit status

- The exit status of the agent or shell when the session ran.
- **1**, message on stderr prefixed `sandbox:`, nothing started:
  - unknown option or more than one `DIR`;
  - `DIR` is not a folder, is `/`, is `$HOME`, or contains `$HOME`;
  - the host user is root;
  - `docker` is not on `PATH` (`sandbox: docker not found; install Docker to use the sandbox`);
  - the Docker daemon is not reachable;
  - the image build failed.

Argument and folder checks happen before any Docker call.

## Environment passed into the container

Only these, and only when set on the host:

- `CLAUDE_CODE_OAUTH_TOKEN`, `ANTHROPIC_API_KEY`
- `TERM`, `COLORTERM`
- `GIT_AUTHOR_NAME`, `GIT_COMMITTER_NAME` (from `git config user.name`), and `GIT_AUTHOR_EMAIL`,
  `GIT_COMMITTER_EMAIL` (from `git config user.email`)
- everything in `~/.config/local/sandbox.env`, if the file exists

The image sets `DISABLE_AUTOUPDATER=1`, `GIT_TERMINAL_PROMPT=0`, `LANG=C.UTF-8` and the cache
variables (research R8).

## Host side effects

- May build or replace the `dev-sessionizer-sandbox` image.
- May create, or with `--reset` remove, this project's cache volume.
- Writes nothing on the host except what the session writes inside `DIR`.

## Install changes

- `~/.config/bin/sandbox` (part of the existing `~/.config/bin` copy).
- New managed path `~/.config/sandbox` (`Dockerfile`, `entrypoint.sh`).
- New override `~/.config/local/sandbox.env`, created once, mode 600.
- Install does not call Docker and succeeds without it.
