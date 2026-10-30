# Quickstart: Validate the Bounded Repo Scan

## Automated

```bash
tests/verify.sh lint     # bash -n, shellcheck, portability gates
tests/verify.sh mac      # smoke tests natively, entry scripts under /bin/bash 3.2
tests/verify.sh linux    # smoke tests in the Debian container
```

Expected: all PASS, including the `dev` scenarios listed in `research.md` R5. These cover the
default depth, `:N` overrides, bad-depth errors, the 200-repo plus 5,000-folder run under
1 s, and timing that does not grow with folders below the depth.

## Manual, on a real machine (SC-001, SC-004, SC-005)

Needs: the change installed (`./install.sh`) and your normal `~/.devconfig`.

1. **Speed**: `time dev --list`. Expected: real time under 1 s (it was about 13 s with
   `~/github.com`).
2. **Nothing lost**: before installing the change, save the old list with
   `dev --list | sort > /tmp/before`. After installing, run
   `comm -23 /tmp/before <(dev --list | sort)`. Expected: only repos more than 3 folders below
   their root (on the author's machine, the two `s1monb/worktrees/perceptiq/*/perceptiq`
   checkouts).
3. **Get deep repos back**: add `~/github.com/s1monb/worktrees:3` to `~/.devconfig`, or
   change the `~/github.com` line to `~/github.com:5`. Run `dev --list | grep worktrees`.
   Expected: both checkouts are listed, and `time dev --list` is still under 1 s.
4. **Bad depth**: add `~/github.com:zero` and run `dev --list; echo $?`. Expected: an error
   naming `~/.devconfig`, the line number and `zero`; exit code 1. Remove the line afterwards.
5. **Picker**: run `dev`, pick a repo, and land in its tmux session (unchanged behaviour).
