FROM debian:stable-slim

# Debian stable ships Neovim 0.10; the config needs >= 0.12 (the vendored blink.cmp v2),
# so Neovim comes from the official release tarball instead of apt.
ARG NVIM_VERSION=v0.12.2

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      bash git tmux fzf tar findutils ca-certificates curl xsel \
 && rm -rf /var/lib/apt/lists/*

RUN arch="$(uname -m | sed 's/aarch64/arm64/')" \
 && curl -fsSL "https://github.com/neovim/neovim/releases/download/${NVIM_VERSION}/nvim-linux-${arch}.tar.gz" \
    | tar -xz -C /opt \
 && mv "/opt/nvim-linux-${arch}" /opt/nvim \
 && ln -s /opt/nvim/bin/nvim /usr/local/bin/nvim

RUN useradd --create-home tester
USER tester
WORKDIR /src
CMD ["bash", "tests/smoke.sh"]
