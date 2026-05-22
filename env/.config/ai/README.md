# claude-container

A minimal Docker wrapper for running [Claude Code](https://claude.ai/code) in an isolated container, with your config and skills persisted from the host.

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/)
- [Node.js](https://nodejs.org/) (for `ai-init`)
- A Claude account with Claude Code access

## Getting started

**1. Clone the repo and add `bin/` to your PATH**

```bash
git clone <repo-url> ~/claude-container
echo 'export PATH="$HOME/claude-container/bin:$PATH"' >> ~/.zshrc  # or ~/.bashrc
source ~/.zshrc
```

**2. Build the Docker image**

```bash
ai-build
```

**3. Install skills (once)**

```bash
ai-init
```

**4. Run Claude Code in any project**

```bash
cd ~/your-project
ai
```

## Commands

| Command | Description |
|---|---|
| `ai` | Launch Claude Code in the current directory |
| `ai-build` | Build (or rebuild) the Docker image |
| `ai-init` | Install skills into `~/.claude` on the host |

## How it works

- Your current directory is mounted as `/workspace` inside the container.
- `~/.claude` and `~/.claude.json` are mounted from the host, so your auth, config, and skills persist across runs.
- Skills installed via `ai-init` run on the host and are available inside the container via the mounted `~/.claude` volume.
