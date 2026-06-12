#!/usr/bin/env bash
# Entry point: ensure the OpenClaw bits that are NOT in the npm core are present on the
# /data volume (version-matched), point the Codex provider at its credential home, then
# start the wrapper.
#
# Not in the npm core, installed here onto /data so they persist + update with the core:
#   - @openclaw/googlechat  (Google Chat channel plugin)
#   - @openclaw/codex       (ChatGPT-subscription / Codex model provider plugin)
#   - @openai/codex         (Codex CLI; provides codex-app-server used by the codex provider)
#
# Codex auth itself is a one-time interactive step (run once, persists on /data):
#   CODEX_HOME=/data/.codex codex login --device-auth
set -uo pipefail

export CODEX_HOME="${CODEX_HOME:-/data/.codex}"
export PATH="/data/npm/bin:${PATH}"
STATE="${OPENCLAW_STATE_DIR:-/data/.openclaw}"
VER="${OPENCLAW_VERSION:-latest}"
mkdir -p "${STATE}" "${CODEX_HOME}" 2>/dev/null || true

# OpenAI Codex CLI (codex-app-server) — required by the codex model provider.
if [ ! -x /data/npm/bin/codex ]; then
  echo "[start] installing @openai/codex CLI ..."
  npm install -g @openai/codex >/dev/null 2>&1 || echo "[start] WARNING: codex CLI install failed (will retry next boot)"
fi

# Install an OpenClaw plugin onto /data, version-matched to the core (idempotent via marker).
install_plugin() {
  local pkg="$1" name="$2"
  local marker="${STATE}/.plugin-${name}-version"
  if [ "$(cat "${marker}" 2>/dev/null || echo none)" != "${VER}" ]; then
    echo "[start] installing ${pkg}@${VER} ..."
    if openclaw plugins install "${pkg}@${VER}"; then
      echo "${VER}" > "${marker}"
      echo "[start] ${name} ready (${VER})"
    else
      echo "[start] WARNING: ${name} install failed (will retry next boot)"
    fi
  else
    echo "[start] ${name} already at ${VER}"
  fi
}
install_plugin "@openclaw/googlechat" "googlechat"
install_plugin "@openclaw/codex" "codex"

if [ -f "${CODEX_HOME}/auth.json" ]; then
  echo "[start] codex credential present (${CODEX_HOME})"
else
  echo "[start] NOTE: no codex credential yet — run: CODEX_HOME=${CODEX_HOME} codex login --device-auth"
fi

exec node src/server.js
