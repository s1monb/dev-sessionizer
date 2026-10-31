# Image for `sandbox`: a coding agent that runs as the host user, with no root and no sudo.
# Built locally by the sandbox command with --build-arg UID=$(id -u) --build-arg GID=$(id -g).
FROM debian:stable-slim

ARG UID
ARG GID

# Agents cannot install system packages (no root), so ship the tools they commonly reach for.
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      git ca-certificates curl ripgrep jq less procps unzip xz-utils zip build-essential \
 && rm -rf /var/lib/apt/lists/*

# Docker Desktop mounts can report other owners; the env passes the host identity, this is a fallback.
RUN git config --system safe.directory '*' \
 && git config --system user.name sandbox \
 && git config --system user.email sandbox@localhost

# macOS GID 20 (staff) is dialout in Debian: reuse an existing group rather than failing.
RUN test -n "$UID" -a -n "$GID" || { echo "build with --build-arg UID=... --build-arg GID=..." >&2; exit 1; } \
 && { getent group "$GID" >/dev/null || groupadd -g "$GID" agent; } \
 && { ! getent passwd "$UID" >/dev/null || { echo "UID $UID already exists in the base image" >&2; exit 1; }; } \
 && useradd -m -d /home/agent -u "$UID" -g "$GID" -s /bin/bash agent \
 && mkdir /cache && chown "$UID:$GID" /cache

ENV LANG=C.UTF-8 \
    DISABLE_AUTOUPDATER=1 \
    GIT_TERMINAL_PROMPT=0 \
    MISE_DATA_DIR=/cache/mise \
    XDG_CACHE_HOME=/cache/xdg \
    npm_config_cache=/cache/npm \
    GOPATH=/cache/go \
    CARGO_HOME=/cache/cargo \
    PATH=/cache/mise/shims:/home/agent/.local/bin:/home/agent/.opencode/bin:$PATH

USER agent
WORKDIR /home/agent

RUN curl -fsSL https://claude.ai/install.sh | bash \
 && curl -fsSL https://opencode.ai/install | bash \
 && curl -fsSL https://mise.run | sh \
 && claude --version && opencode --version && mise --version \
 && rm -rf ~/.claude ~/.claude.json

COPY --chmod=755 entrypoint.sh /usr/local/bin/sandbox-entrypoint
ENTRYPOINT ["sandbox-entrypoint"]
