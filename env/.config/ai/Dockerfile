FROM node:22-slim

# Install system dependencies required by Claude Code
RUN apt-get update && apt-get install -y \
    git \
    curl \
    less \
    && rm -rf /var/lib/apt/lists/*

RUN npm install -g @anthropic-ai/claude-code

RUN mkdir -p /home/user && chmod 777 /home/user

ENV DISABLE_AUTOUPDATER=true
ENTRYPOINT ["claude"]
