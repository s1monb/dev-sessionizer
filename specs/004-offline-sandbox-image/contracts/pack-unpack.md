# Contract: `pack.sh` and `unpack.sh` changes

## `pack.sh`

```text
./pack.sh [--uid N --gid N [--arch amd64|arm64]] [OUTPUT]
```

| Part | Meaning |
|------|---------|
| `OUTPUT` | Archive path, default `./dev-sessionizer.tar.gz` (unchanged) |
| `--uid N`, `--gid N` | Target user's ids. Both given: build and include the sandbox image |
| `--arch A` | Target architecture. Default: the build machine's (`uname -m` mapped) |
| `-h`, `--help` | Usage on stdout, exit 0 |

Options may come before or after `OUTPUT`.

Without `--uid`/`--gid`: behaviour, output and Docker use are exactly as today.

With them, in order:

1. Validate the arguments (data-model.md, "Pack validation"). Check that Docker is on `PATH` and
   the daemon is reachable.
2. Stage the environment and runtime state as today.
3. `docker build --pull --no-cache --platform linux/A --build-arg UID=N --build-arg GID=N
   --build-arg OFFLINE=1 --label dev-sessionizer.packed=1 --label dev-sessionizer.uid=N
   --label dev-sessionizer.gid=N --label dev-sessionizer.files=F -t dev-sessionizer-sandbox:packed
   env/.config/sandbox`. Build output goes to stderr.
4. `docker save` into `STAGE/dev-sessionizer/sandbox-image.tar`.
5. Add `sandbox_uid`, `sandbox_gid` and `sandbox_arch` to `MANIFEST`.
6. Write the archive to a temp file next to OUTPUT, then rename it into place.
7. Always (exit trap): remove the staging folder, the temp file and the `:packed` tag.

Exit status: 0 on success. 1 with a `dev-sessionizer:` message on stderr for a bad argument,
missing Docker, a failed build, save or write. On failure no file is left at OUTPUT; a file that
was already at OUTPUT is left unchanged.

## `unpack.sh`

No new arguments. After `install.sh`, and before the runtime-state platform check:

| Condition | Action | Exit status |
|-----------|--------|-------------|
| No `sandbox-image.tar` | nothing (today) | unchanged |
| `sandbox_arch` ≠ this machine | message: image is for A, not loaded | continue |
| `docker` missing or daemon unreachable | message: not loaded, with the `docker load -i PATH` and `docker tag` commands to run later | continue |
| load or tag fails | message with Docker's error | continue |
| loaded | `docker load -i`, `docker tag dev-sessionizer-sandbox:packed dev-sessionizer-sandbox:latest`, `docker image rm dev-sessionizer-sandbox:packed` (removes the tag only); log `loaded sandbox image for uid U gid G` | continue |
| loaded, and U/G ≠ `id -u`/`id -g` | also warn: `sandbox` will refuse it for this user | continue |

Unpack's exit status stays as today: the image never makes unpack fail. Runtime-state handling is
unchanged.

## Install

The `sandbox.env` template written for a new file gains:

```text
# Agent started by `sandbox` when none is named: claude (default) or opencode.
# SANDBOX_AGENT=opencode
```

Existing files are not touched.
