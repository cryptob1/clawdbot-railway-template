#!/usr/bin/env bash
# Entry point: ensure the googlechat channel plugin (not bundled in the npm core) is
# installed on the /data volume at the same version as the core, then start the wrapper.
set -uo pipefail

STATE="${OPENCLAW_STATE_DIR:-/data/.openclaw}"
VER="${OPENCLAW_VERSION:-latest}"
MARKER="${STATE}/.googlechat-plugin-version"

mkdir -p "${STATE}" 2>/dev/null || true

if [ "$(cat "${MARKER}" 2>/dev/null || echo none)" != "${VER}" ]; then
  echo "[start] installing @openclaw/googlechat@${VER} into ${STATE} ..."
  if openclaw plugins install "@openclaw/googlechat@${VER}"; then
    echo "${VER}" > "${MARKER}"
    echo "[start] googlechat plugin ready (${VER})"
  else
    echo "[start] WARNING: googlechat plugin install failed; starting anyway (will retry next boot)"
  fi
else
  echo "[start] googlechat plugin already at ${VER}"
fi

exec node src/server.js
