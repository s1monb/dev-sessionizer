# Quickstart: validating the offline sandbox image

Contracts: [pack-unpack.md](contracts/pack-unpack.md), [sandbox.md](contracts/sandbox.md).
Rules: [data-model.md](data-model.md).

## Automated

```bash
tests/verify.sh lint mac linux   # fake-docker scenarios: pack validation, unpack load, packed checks, SANDBOX_AGENT
tests/verify.sh sandbox          # real Docker: scenario_agent_packed (pack for other ids, load, run offline)
```

Expected: every scenario `ok`.

## By hand

### 1. Pack for another user (connected machine)

```bash
./pack.sh --uid 1500 --gid 1500 --arch amd64 /tmp/ds.tar.gz
tar -tzf /tmp/ds.tar.gz | grep sandbox-image.tar
tar -xzOf /tmp/ds.tar.gz dev-sessionizer/MANIFEST    # sandbox_uid=1500 sandbox_gid=1500 sandbox_arch=amd64
docker image ls dev-sessionizer-sandbox               # no :packed tag left behind
./pack.sh --uid 0 --gid 1500 /tmp/bad.tar.gz; echo $? # 1, and /tmp/bad.tar.gz does not exist
```

Repeat the first line on macOS (Docker Desktop) for an `amd64` target.

### 2. Unpack on the target, offline

On a Linux machine with Docker and no outbound network, as the user with ids 1500:1500:

```bash
tar -xzf ds.tar.gz && ./dev-sessionizer/unpack.sh   # "loaded sandbox image for uid 1500 gid 1500"
cd ~/some-project
sandbox shell -- -c 'id; claude --version; opencode --version; env | grep OPENCODE_DISABLE'
```

Expected: no build output; `uid=1500 gid=1500`; both versions print; `AUTOUPDATE`,
`MODELS_FETCH` and `LSP_DOWNLOAD` are set to `1`.

To simulate the target on a connected machine, use `--network none` on the `sandbox` call.
For different ids, unpack and run as a test user created with those ids.

### 3. Refusals on the target

```bash
sudo -u otheruser sandbox shell   # "image was packed for uid 1500 gid 1500, you are uid ..."
sandbox --rebuild                 # "image was packed on another machine; repack there ..."
```

### 4. OpenCode starts offline

```bash
time sandbox opencode -- --version   # well under 10 s
sandbox opencode                     # answers using the target's model server
```

### 5. Default agent

```bash
echo 'SANDBOX_AGENT=opencode' >> ~/.config/local/sandbox.env
sandbox            # OpenCode
sandbox claude     # Claude Code
sandbox shell      # bash
sed -i.bak 's/^SANDBOX_AGENT=.*/SANDBOX_AGENT=vim/' ~/.config/local/sandbox.env
sandbox            # "SANDBOX_AGENT=vim in ~/.config/local/sandbox.env is not supported (claude, opencode)"
```

### 6. No bypass-permissions dialog

With a host `~/.claude/settings.json` that has no `skipDangerousModePermissionPrompt`:

```bash
sandbox            # Claude Code opens straight into the session
grep -c skipDangerousModePermissionPrompt ~/.claude/settings.json   # 0: host file unchanged
```
