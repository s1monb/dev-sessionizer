# Quickstart: Agent Sandbox

## Automated

```bash
tests/verify.sh lint      # includes the sandbox script and entrypoint
tests/verify.sh linux     # smoke: install deploys sandbox; no-docker and $HOME refusals
tests/verify.sh mac       # same smoke scenarios natively
tests/verify.sh sandbox   # needs Docker + network: scenario_agent_* in tests/smoke.sh (research R12)
```

Run `tests/verify.sh sandbox` on macOS (Docker Desktop) and on a Linux host (Docker Engine). On a
Linux host whose bridge network has no internet, run it with `SANDBOX_NETWORK=host`.

Expected: every line `PASS`.

## Manual

Prerequisites: `./install.sh` run; Docker running; a Claude token in
`~/.config/local/sandbox.env` (`CLAUDE_CODE_OAUTH_TOKEN=…` from `claude setup-token`).

1. **First run** (User Story 1, 2): `mkdir -p /tmp/sbx && cd /tmp/sbx && git init && sandbox`. The
   image builds once, then Claude Code starts without a login step, in skip-permissions mode, in
   `/tmp/sbx`. Ask it to create `hello.txt` and commit it, then to `touch ~/../../etc/x` and to
   `git push`. Quit.
   - `ls -ln hello.txt` shows your UID/GID.
   - `git log` shows the commit with your name.
   - The push failed.
   - `docker ps -a` shows no sandbox container.
2. **Config is read-only** (User Story 2): `shasum ~/.claude/settings.json`. Run
   `sandbox shell -- -c 'echo "{}" > ~/.claude/settings.json; echo x >> /host/claude/settings.json'`.
   The second write fails, and the checksum is unchanged.
3. **OpenCode** (User Story 3): `sandbox opencode`. It starts with your providers logged in.
4. **Toolchains and cache** (User Story 4): add `.tool-versions` with `node 22`. Run
   `sandbox shell -- -c 'node --version'` twice; the second run downloads nothing. Run
   `sandbox --reset shell -- -c true`; the next run downloads again.
5. **Refusals**: `sandbox ~` and `sandbox /` exit 1 with a message.
6. **Start time** (SC-001): `time sandbox shell -- -c true` in a project without tools takes under
   5 s once the image exists.
7. **Network override**: `sandbox --network none shell -- -c 'curl -sI https://example.com'` fails;
   without the option it succeeds (on Linux hosts with a broken bridge, `--network host`).
