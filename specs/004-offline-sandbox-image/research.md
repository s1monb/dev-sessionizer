# Research: Offline Sandbox Image and Default Agent

Checked on 2026-11-03 against the binaries in the current sandbox image: Claude Code 2.1.316 and
OpenCode 1.19.5 (by searching the shipped binaries for the setting and flag names).

## R1. How the image travels

- **Decision**: `pack.sh` runs `docker save` on the built image into
  `dev-sessionizer/sandbox-image.tar` inside the staging folder, uncompressed. The outer
  `tar -czf` compresses the whole archive. `unpack.sh` runs `docker load -i` on it.
- **Rationale**: Uses the archive the developer already carries (clarification B). One gzip pass,
  not two. `docker load` needs no network and no registry.
- **Alternatives**: a local registry on the target (needs a running registry, too much); a
  separate file next to the archive (option A, not chosen); `docker export`/`import` (loses `ENV`,
  `USER`, `ENTRYPOINT` and labels).

## R2. Image name during pack and on the target

- **Decision**: Pack builds and saves the tag `dev-sessionizer-sandbox:packed`, then removes that
  tag on the build machine (exit trap). Unpack loads it, tags it `dev-sessionizer-sandbox:latest`
  (the name `sandbox` already uses), and removes the `:packed` tag.
- **Rationale**: Building straight to `:latest` would replace the packer's own local sandbox image
  with one for someone else's ids. A fixed tag means unpack knows which tag to retag, so it does not
  have to parse the output of `docker load`.
- **Alternatives**: making `sandbox` look up several names (spreads the special case into the command).

## R3. Image identity

- **Decision**: Docker labels set with `--label` at build time:
  `dev-sessionizer.packed=1`, `dev-sessionizer.uid`, `dev-sessionizer.gid`,
  `dev-sessionizer.files` (cksum of `Dockerfile` + `entrypoint.sh`). Local builds also set
  `.uid`, `.gid` and `.files`, and keep `dev-sessionizer.hash` (files-uid-gid) so they behave as
  today. Architecture comes from `docker image inspect -f '{{.Architecture}}'`, not a label.
- **Rationale**: Labels survive `save`/`load` and are read with the `inspect` call `sandbox`
  already makes. No side file can drift from the image.
- **Alternatives**: a JSON file next to the image (gets out of sync after a later `docker load`).

## R4. Target architecture

- **Decision**: `--arch amd64|arm64`, default from `uname -m` (`x86_64`→`amd64`,
  `aarch64`/`arm64`→`arm64`, anything else → error asking for `--arch`). The build passes
  `--platform linux/ARCH`. `MANIFEST` records `sandbox_arch`; unpack skips loading when it differs
  from the target's mapped `uname -m`.
- **Rationale**: The developer packs from a Mac (arm64) for Linux amd64 targets. Docker Desktop
  builds other architectures with its built-in emulation. Docker Engine on Linux needs
  `binfmt`/QEMU for that, which the README mentions. Same-architecture packs need nothing extra.
- **Risk**: With the containerd image store, `docker save` of an image built for another platform
  may need `--platform`. Pack passes `--platform linux/ARCH` to `docker save` when
  `docker save --help` lists it, and leaves it out otherwise.

## R5. Fresh build when packing

- **Decision**: Pack always builds with `--pull --no-cache`.
- **Rationale**: The target cannot update later, so the image should carry current agent versions
  and a current base. This is the same as `sandbox --rebuild`.

## R6. Unpack ordering

- **Decision**: In `unpack.sh`, load the image after `install.sh` and before the runtime-state
  platform check. That check currently runs `exit 0` on a mismatch, which would skip a later load.
- **Rationale**: Runtime state (Neovim) and the image have separate platform rules. An archive packed
  on macOS for a Linux target has mismatched runtime state but a matching image.
- Unpack never fails because of the image. Missing Docker, a stopped daemon, a different
  architecture or a failed load each print one `dev-sessionizer:` message on stderr with the reason
  and the manual command (`docker load -i …/sandbox-image.tar`). A uid/gid that differs from
  the user running unpack prints a warning after loading.

## R7. Packed image on a connected machine

- **Decision**: `sandbox` never rebuilds an image labelled `packed=1`. `--rebuild` with a packed
  image exits 1 and tells the developer to repack, or to remove the image
  (`docker image rm dev-sessionizer-sandbox`) to go back to local builds.
- **Rationale**: FR-008/FR-011. Keeps the rule simple: the packed label is what decides, not
  whether the network works.

## R8. OpenCode network calls (verified in OpenCode 1.19.5)

| Flag | Effect | Where set |
|------|--------|-----------|
| `OPENCODE_DISABLE_AUTOUPDATE=1` | No update check at start | Dockerfile `ENV`, every image (FR-013) |
| `OPENCODE_DISABLE_MODELS_FETCH=1` | No download of `https://models.opencode.ai/api.json` (10 s timeout, 2 retries when offline) | entrypoint, when `SANDBOX_OFFLINE=1` |
| `OPENCODE_DISABLE_LSP_DOWNLOAD=1` | No automatic language server download | entrypoint, when `SANDBOX_OFFLINE=1` |

- **Decision**: The Dockerfile gains `ARG OFFLINE=0` and `ENV SANDBOX_OFFLINE=$OFFLINE`. Pack builds
  with `--build-arg OFFLINE=1`. No catalog snapshot is shipped: with the fetch off and no cached
  catalog, OpenCode starts with an empty catalog, and the providers and models come from the
  target's own OpenCode config (the developer keeps a separate model list there). Connected images
  keep the live catalog.
- **Alternative rejected**: baking a catalog snapshot into the image and pointing
  `OPENCODE_MODELS_PATH` at it. Not needed when the target config lists its models, and it would
  show models the target cannot reach.
- **Not changed**: `OPENCODE_DISABLE_DEFAULT_PLUGINS`. Built-in plugins ship inside the binary, and
  turning them off would remove built-in provider logins. Plugins listed in the user's config are
  the developer's responsibility (spec clarification).
- **Alternative rejected**: setting the flags with `docker run -e` from `sandbox`. The image is what
  knows it is offline. Keeping this in the image means `sandbox shell` behaves the same.

## R9. Claude Code bypass-permissions dialog (verified in Claude Code 2.1.316)

- Claude Code records acceptance of the dialog as `"skipDangerousModePermissionPrompt": true`
  in user settings (`~/.claude/settings.json`). It also honours the key in local, flag and policy
  settings. The older `bypassPermissionsModeAccepted` in `~/.claude.json` is migrated to it. The
  dialog shows every session today because the entrypoint copies the host's `settings.json`, which
  lacks the key, and the accepted copy is thrown away when the container ends.
- **Decision**: After copying host config, the entrypoint sets the key in the container's
  `~/.claude/settings.json` with `jq` (creating `{}` first if the file is missing). If the host file
  is not valid JSON, it prints a one-line warning and leaves it alone. Claude Code will then show
  the dialog, which is the safe failure.
- **Rationale**: The host file is mounted read-only and copied, so the host stays unchanged (FR-020).
  User settings are where Claude Code itself writes the key.
- **Alternative**: `claude --settings '{"skipDangerousModePermissionPrompt":true}'` (flag settings).
  Works, but would collide with a `--settings` the developer passes after `--`.

## R10. Default agent from `sandbox.env`

- **Decision**: `sandbox` reads `~/.config/local/sandbox.env` line by line with `IFS='=' read`. It
  ignores blank lines and lines starting with `#`, and takes the last `SANDBOX_AGENT=` value
  verbatim (no trimming, no unquoting). The value must be `claude` or `opencode`. It is read only
  when no mode is given on the command line, and checked before any Docker call.
- **Rationale**: Docker's `--env-file` uses the same rules (verbatim values, last one wins, `#`
  comments), so the file means the same thing to both readers. The file is never sourced.
- `shell` is not allowed as a default: a default that never starts an agent would surprise.
- **Alternative**: a `SANDBOX_AGENT` shell variable like `SANDBOX_NETWORK`. The developer asked
  for `sandbox.env`.

## R11. Testing without Docker

- **Decision**: `tests/fake-docker` is a small bash script put first on `PATH` as `docker`. It
  appends each call to `$FAKE_DOCKER_LOG` and answers `info`, `image inspect`
  (labels and architecture from `FAKE_DOCKER_*` variables), `build`, `save` (writes a small file),
  `load`, `tag`, `image rm`, `volume …` and `run` (prints its arguments). Smoke scenarios check
  the logged calls and messages.
- **Rationale**: SC-004 asks for an automated test of the refusal and selection rules. These must
  run in `mac` and `linux` targets that have no Docker. One real-Docker scenario
  (`scenario_agent_packed`) checks the full pack→load→run path in `tests/verify.sh sandbox`.
