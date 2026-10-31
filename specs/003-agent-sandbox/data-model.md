# Data Model: Agent Sandbox

## Sandbox image

- **Tag**: `dev-sessionizer-sandbox`
- **Label** `dev-sessionizer.hash`: `cksum` of `Dockerfile` + `entrypoint.sh` + host UID + host GID.
- **Built when**: missing, label differs from the current value, or `--rebuild` (then with
  `--pull --no-cache`).
- **Contains**: user `agent` (host UID, host GID group), `/home/agent`, `/cache` owned by `agent`,
  Claude Code, OpenCode, mise, base tools (research R7). No sudo.

## Tool cache (per project)

- **Name**: `dev-sessionizer-sandbox-<name>-<crc>`
  - `<name>`: project folder basename with every character outside `[A-Za-z0-9_.-]` replaced by `-`.
  - `<crc>`: first field of `printf %s "$project" | cksum`, where `$project` is the physical
    absolute path (`pwd -P`).
- **Mounted at**: `/cache`. Layout in research R8.
- **Lifecycle**: created by Docker on first run of that project; kept across sessions; removed by
  `--reset`. Never removed automatically.

## Sandbox session

- **One container**, `--rm`, no fixed name (Docker picks one), so several sessions can run at once,
  including on the same project.
- **Mounts**:

  | Source | Target | Mode |
  |--------|--------|------|
  | project (physical path) | same path | rw |
  | tool cache volume | `/cache` | rw |
  | `~/.claude` | `/host/claude` | ro, if present |
  | `~/.claude.json` | `/host/claude.json` | ro, if present |
  | `~/.config/opencode` | `/host/opencode-config` | ro, if present |
  | `~/.local/share/opencode/auth.json` | `/host/opencode-auth.json` | ro, if present |

- **States**: starting (image check/build → container start → entrypoint copies config → `mise
  install` if configured) → running (agent or shell) → ended (container removed; project changes and
  cache remain).

## Host agent config

Read-only inputs, listed above. Copy rules and excluded entries: research R5. A missing source is
not mounted and not an error.

## Sandbox env file

- **Path**: `~/.config/local/sandbox.env`. User-owned override, created once by install with mode
  600 and a commented example. Never written again by install.
- **Format**: Docker `--env-file`: one `KEY=value` per line, `#` comments, no quoting or expansion.
  It is never sourced by a shell.
- **Typical content**: `CLAUDE_CODE_OAUTH_TOKEN=…`, provider keys for OpenCode.

## Project path validation

Resolved with `cd "$dir" && pwd -P`. Rejected (exit 1, nothing started) when:

- it does not exist or is not a folder;
- it is `/`;
- it equals the physical `$HOME` or is an ancestor of it (`$HOME` starts with `<path>/`).
