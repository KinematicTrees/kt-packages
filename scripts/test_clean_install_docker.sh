#!/usr/bin/env bash
set -euo pipefail
REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
INSTALL_ROOT="/opt/kt"

docker run --rm \
  -v "$REPO_DIR:/workspace:ro" \
  -w /workspace \
  debian:bookworm-slim \
  bash -lc '
    set -euo pipefail
    apt-get update >/dev/null
    apt-get install -y --no-install-recommends git ca-certificates curl xz-utils unzip coreutils >/dev/null

    ./scripts/install_from_release_track.sh \
      --repo-url file:///workspace \
      --repo-ref main \
      --node-version 20.11.1 \
      --module-version 0.1.0 \
      --platform linux-x64 \
      --modules model-loader,viewer-runtime,ik-runtime,ik-control \
      --install-root /opt/kt

    timeout 3s env KT_HOME=/opt/kt /opt/kt/bin/kt-run-module model-loader 0.1.0 >/tmp/model-loader.out 2>&1 || true
    NODE_BIN=$(find /opt/kt/runtime -type f -path "*/bin/node" | head -n1)
    "$NODE_BIN" --version

    test -f /opt/kt/modules/model-loader/0.1.0/linux-x64/processes/p1-loader/src/main.mjs
    test -f /opt/kt/modules/viewer-runtime/0.1.0/linux-x64/processes/p2-viewer-runtime/src/main.mjs
    test -f /opt/kt/modules/ik-runtime/0.1.0/linux-x64/processes/p3-ik-runtime/src/main.mjs
    test -f /opt/kt/modules/ik-control/0.1.0/linux-x64/processes/p4-ik-control/src/main.mjs

    echo "Clean install test passed"
  '
