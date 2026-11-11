# Data Model: Offline Sandbox Image and Default Agent

## Packed image (inside the archive)

| Item | Value |
|------|-------|
| Path in archive | `dev-sessionizer/sandbox-image.tar` (output of `docker save`) |
| Tag inside | `dev-sessionizer-sandbox:packed` |
| Present | only when pack ran with `--uid` and `--gid` |

## MANIFEST keys

Existing: `os`, `arch`, `created` (host that packed, for runtime state).

New, only when the archive holds an image:

| Key | Example | Rule |
|-----|---------|------|
| `sandbox_uid` | `1500` | positive integer |
| `sandbox_gid` | `1500` | positive integer |
| `sandbox_arch` | `amd64` | `amd64` or `arm64` |

Unpack reads them with the existing `IFS='=' read` loop and ignores unknown keys.

## Image labels

| Label | Local build | Packed build |
|-------|-------------|--------------|
| `dev-sessionizer.hash` | `FILES-UID-GID` (unchanged meaning) | not set |
| `dev-sessionizer.files` | cksum of `Dockerfile`+`entrypoint.sh` | same |
| `dev-sessionizer.uid` | `id -u` | `--uid` |
| `dev-sessionizer.gid` | `id -g` | `--gid` |
| `dev-sessionizer.packed` | not set | `1` |

Image env: `SANDBOX_OFFLINE` is `1` for packed builds and `0` otherwise. Architecture is read from
the image (`.Architecture`).

## Decision table: what `sandbox` does with the image

Evaluated after argument, folder and Docker checks.

| Image state | `--rebuild` | Result |
|-------------|-------------|--------|
| none | any | build locally (today) |
| local, `hash` matches | no | use |
| local, `hash` differs | any | rebuild locally (today) |
| local | yes | rebuild locally (today) |
| packed, uid/gid = `id -u`/`id -g`, files match | no | use |
| packed, ids match, files differ | no | notice `sandbox: image was packed from older sandbox files; repack to update`, then use |
| packed, ids differ | any | exit 1: `sandbox: image was packed for uid U gid G, you are uid u gid g` |
| packed | yes | exit 1: `sandbox: image was packed on another machine; repack there, or 'docker image rm dev-sessionizer-sandbox' to build locally` |

## Default agent setting

| Field | Rule |
|-------|------|
| File | `~/.config/local/sandbox.env` (user-owned, mode 600, created once by install) |
| Line | `SANDBOX_AGENT=claude` or `SANDBOX_AGENT=opencode` |
| Parsing | `#` lines and blank lines ignored; the last `SANDBOX_AGENT=` line wins; value taken verbatim |
| Precedence | a mode named on the command line (`claude`, `opencode`, `shell`) > `SANDBOX_AGENT` > `claude` |
| Invalid | exit 1 before any Docker call: `sandbox: SANDBOX_AGENT=VALUE in ~/.config/local/sandbox.env is not supported (claude, opencode)` |

## Pack validation

| Input | Rule |
|-------|------|
| `--uid`, `--gid` | both or neither; digits only; not `0` |
| `--arch` | `amd64` or `arm64`; only with ids; default from `uname -m` |
| Docker | needed only with ids: on `PATH` and daemon reachable |

All checks run before staging. Any failure exits 1 with a `dev-sessionizer:` message, and no file
exists at OUTPUT afterwards. The archive is written to a temp file next to OUTPUT and renamed into
place.
