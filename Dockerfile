# OpenClaw on Railway — npm-based image (fork of vignesh07/clawdbot-railway-template).
#
# Differences from upstream:
#  - Installs OpenClaw from npm instead of building from source (seconds vs minutes,
#    no build-script fragility). The Control UI now ships in the npm package.
#  - The googlechat channel plugin is NOT in the npm core, so it is installed at first
#    boot onto the /data volume (version-matched, via start.sh).
#  - Wrapper (src/server.js) carries two required fixes (see that file): gateway auth
#    mode "none", and body-parser scoped to /setup so webhook bodies reach the gateway.
FROM node:22-bookworm
ENV NODE_ENV=production

# Runtime deps + toolchain (most native deps use prebuilds, but keep a compiler available).
RUN apt-get update \
  && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    ca-certificates tini python3 python3-venv git curl make g++ \
  && rm -rf /var/lib/apt/lists/*

# `openclaw update` / plugin installs can use pnpm.
RUN corepack enable && corepack prepare pnpm@10.23.0 --activate

# OpenClaw version. Bump this (or override OPENCLAW_VERSION as a Railway build variable)
# to update OpenClaw — the googlechat plugin is pinned to the same version at boot.
ARG OPENCLAW_VERSION=2026.6.6
ENV OPENCLAW_VERSION=${OPENCLAW_VERSION}

# Install OpenClaw core from npm into the image (fast; no source build).
RUN npm install --prefix /opt/openclaw --omit=dev "openclaw@${OPENCLAW_VERSION}" \
  && npm cache clean --force

# Provide an `openclaw` executable pointing at the npm-installed core.
RUN printf '%s\n' '#!/usr/bin/env bash' 'exec node /opt/openclaw/node_modules/openclaw/dist/entry.js "$@"' > /usr/local/bin/openclaw \
  && chmod +x /usr/local/bin/openclaw

# Tell the wrapper which entry to spawn for the gateway.
ENV OPENCLAW_ENTRY=/opt/openclaw/node_modules/openclaw/dist/entry.js

WORKDIR /app

# Wrapper deps (installed with default npm config).
COPY package.json ./
RUN npm install --omit=dev && npm cache clean --force

COPY src ./src
COPY start.sh ./start.sh
RUN chmod +x ./start.sh

# Persist user-installed tools / plugins on the Railway volume (runtime).
ENV NPM_CONFIG_PREFIX=/data/npm
ENV NPM_CONFIG_CACHE=/data/npm-cache
ENV PNPM_HOME=/data/pnpm
ENV PNPM_STORE_DIR=/data/pnpm-store
ENV PATH="/data/npm/bin:/data/pnpm:/usr/local/bin:${PATH}"

# Wrapper listens on Railway's injected $PORT (default 8080 in the wrapper). Do not hardcode PORT.
EXPOSE 8080

ENTRYPOINT ["tini", "--"]
CMD ["./start.sh"]
