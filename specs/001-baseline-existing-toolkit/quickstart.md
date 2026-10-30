# Quickstart: Validate the Baseline

This guide proves the spec end to end. The commands and their exit codes are defined in
[contracts/cli.md](./contracts/cli.md).

## Prerequisites

- **macOS**: bash, git, tmux, nvim, fzf. Docker is needed for the Linux and lint targets.
- The repo is cloned with its submodules: `git clone --recursive …`, or run
  `git submodule update --init --recursive` afterwards.

## 1. Automated verification (US1, SC-003)

```bash
tests/verify.sh            # lint + linux + mac
```

Expected: three `PASS` lines in under 5 minutes, and `~` unchanged (`ls -la ~/.config` looks the
same before and after).

**Planted-defect check**: add `sed -i 's/a/b/' x` to any shipped script, then run
`tests/verify.sh lint`. Expected: `FAIL lint` naming the file and line. Revert the change
afterwards.

## 2. Install and idempotency (US2, SC-001, SC-002)

This is covered by the smoke test. To run it by hand in a sandbox:

```bash
export HOME=$(mktemp -d)
./install.sh && ./install.sh
bash -ic 'echo $PS1' | grep -q . && echo prompt-ok
nvim --headless +qa 2>&1 | grep -c . # expect 0
```

**Missing pre-requisite**: run `PATH=/usr/bin:/bin ./install.sh` in a sandbox home that has no
tmux on that PATH. Expected: exit 1 and `missing: … tmux …`, and the sandbox home is still empty.

## 3. Overrides survive (US3)

```bash
echo 'vim.g.local_marker = 1' >> ~/.config/local/nvim.lua
echo 'set -g @local_marker 1'  >> ~/.config/local/tmux.conf
./install.sh
nvim --headless '+lua io.write(vim.g.local_marker)' +qa     # prints 1
```

## 4. Airgapped transfer (US4, SC-004)

```bash
./pack.sh /tmp/ds.tar.gz
tests/verify.sh linux    # includes the unpack run under --network none
```

To check by hand on another machine: `tar -xzf ds.tar.gz && ./dev-sessionizer/unpack.sh`.
Expected: the editor opens with its language servers. When the source and target platforms
differ, the mismatch warning is printed.

## 5. Session picker (US5, SC-005)

```bash
printf '%s\n' '# roots' '~/github.com' '$HOME/does-not-exist' > ~/.devconfig
dev                         # pick a repo → lands in its session
dev                         # pick the same repo → switches, no duplicate (tmux ls)
mv ~/.devconfig{,.bak}; dev # prints how to create ~/.devconfig, exit 1
```

## 6. Helpers and removals (US6, SC-006, SC-007)

```bash
esc-caps-swap        # on macOS: "requires GNOME (gsettings)", exit 1
ls ~/.config/bin     # dev, dev-gc, esc-caps-swap only
git ls-files env/.config/nvim | wc -l   # a handful, not ~375
```
