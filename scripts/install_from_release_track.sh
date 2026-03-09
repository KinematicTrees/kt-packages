#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<USAGE
Usage:
  $0 \
    --repo-url <git repo url> \
    --repo-ref <ref> \
    --node-version <version> \
    --module-version <version> \
    --platform <platform> \
    --modules <comma-separated> \
    --install-root <path>

Example:
  $0 --repo-url https://chimera.tail6403fe.ts.net/git/KinematicTrees/kt-packages.git \
     --repo-ref main --node-version 20.11.1 --module-version 0.1.0 \
     --platform linux-x64 --modules model-loader,viewer-runtime \
     --install-root /opt/kt
USAGE
}

REPO_URL=""
REPO_REF="main"
NODE_VERSION=""
MODULE_VERSION=""
PLATFORM="linux-x64"
MODULES=""
INSTALL_ROOT=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo-url) REPO_URL="$2"; shift 2 ;;
    --repo-ref) REPO_REF="$2"; shift 2 ;;
    --node-version) NODE_VERSION="$2"; shift 2 ;;
    --module-version) MODULE_VERSION="$2"; shift 2 ;;
    --platform) PLATFORM="$2"; shift 2 ;;
    --modules) MODULES="$2"; shift 2 ;;
    --install-root) INSTALL_ROOT="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $1"; usage; exit 1 ;;
  esac
done

[[ -n "$REPO_URL" && -n "$NODE_VERSION" && -n "$MODULE_VERSION" && -n "$MODULES" && -n "$INSTALL_ROOT" ]] || {
  echo "Missing required args" >&2
  usage
  exit 1
}

WORKDIR=$(mktemp -d)
trap 'rm -rf "$WORKDIR"' EXIT

echo "[1/6] Cloning release repo..."
if [[ -n "${GIT_TOKEN:-}" ]]; then
  cat > "$WORKDIR/askpass.sh" <<'ASK'
#!/usr/bin/env bash
case "$1" in
  *Username*) echo "x-access-token" ;;
  *) echo "${GIT_TOKEN}" ;;
esac
ASK
  chmod +x "$WORKDIR/askpass.sh"
  export GIT_ASKPASS="$WORKDIR/askpass.sh"
  export GIT_TERMINAL_PROMPT=0
fi

git clone --quiet --branch "$REPO_REF" "$REPO_URL" "$WORKDIR/repo"

mkdir -p "$INSTALL_ROOT" "$INSTALL_ROOT/cache"

runtime_rel="runtimes/node/${NODE_VERSION}/${PLATFORM}"
runtime_tgz="$WORKDIR/repo/${runtime_rel}/kt-runtime-node-${NODE_VERSION}-${PLATFORM}.tar.gz"
runtime_checksums="$WORKDIR/repo/${runtime_rel}/checksums.txt"

[[ -f "$runtime_tgz" && -f "$runtime_checksums" ]] || {
  echo "Runtime artifact/checksum missing under ${runtime_rel}" >&2
  exit 1
}

echo "[2/6] Verifying runtime checksum..."
(
  cd "$(dirname "$runtime_tgz")"
  sha256sum -c checksums.txt
)

echo "[3/6] Installing runtime..."
tar -xzf "$runtime_tgz" -C "$INSTALL_ROOT"

IFS=',' read -r -a module_arr <<< "$MODULES"

for m in "${module_arr[@]}"; do
  rel="modules/${m}/${MODULE_VERSION}/${PLATFORM}"
  mod_tgz="$WORKDIR/repo/${rel}/robot-${m}-${MODULE_VERSION}-${PLATFORM}.tar.gz"
  mod_checksums="$WORKDIR/repo/${rel}/checksums.txt"
  [[ -f "$mod_tgz" && -f "$mod_checksums" ]] || {
    echo "Module artifact/checksum missing for ${m} under ${rel}" >&2
    exit 1
  }

  echo "[4/6] Verifying module checksum: ${m}"
  (
    cd "$(dirname "$mod_tgz")"
    sha256sum -c checksums.txt
  )

  echo "[5/6] Installing module: ${m}"
  mkdir -p "$INSTALL_ROOT/modules/${m}/${MODULE_VERSION}/${PLATFORM}"
  tar -xzf "$mod_tgz" -C "$INSTALL_ROOT/modules/${m}/${MODULE_VERSION}/${PLATFORM}"
done

echo "[6/6] Creating launcher..."
mkdir -p "$INSTALL_ROOT/bin"
cat > "$INSTALL_ROOT/bin/kt-run-module" <<'RUN'
#!/usr/bin/env bash
set -euo pipefail
if [[ $# -lt 2 ]]; then
  echo "Usage: kt-run-module <module-name> <module-version> [args...]" >&2
  exit 1
fi
MODULE="$1"; shift
VERSION="$1"; shift
PLATFORM="${KT_PLATFORM:-linux-x64}"
KT_HOME="${KT_HOME:-$(cd "$(dirname "$0")/.." && pwd)}"
NODE_BIN=$(find "$KT_HOME/runtime" -type f -path '*/bin/node' | head -n1)
if [[ -z "${NODE_BIN:-}" ]]; then
  echo "Node runtime not found under $KT_HOME/runtime" >&2
  exit 1
fi

case "$MODULE" in
  model-loader) ENTRY="processes/p1-loader/src/main.mjs" ;;
  viewer-runtime) ENTRY="processes/p2-viewer-runtime/src/main.mjs" ;;
  ik-runtime) ENTRY="processes/p3-ik-runtime/src/main.mjs" ;;
  ik-control) ENTRY="processes/p4-ik-control/src/main.mjs" ;;
  *) echo "Unknown module: $MODULE" >&2; exit 1 ;;
esac

BASE="$KT_HOME/modules/${MODULE}/${VERSION}/${PLATFORM}"
TARGET="$BASE/$ENTRY"
[[ -f "$TARGET" ]] || { echo "Entrypoint not found: $TARGET" >&2; exit 1; }
exec "$NODE_BIN" "$TARGET" "$@"
RUN
chmod +x "$INSTALL_ROOT/bin/kt-run-module"

echo "Install complete at: $INSTALL_ROOT"
echo "Try: KT_HOME=$INSTALL_ROOT $INSTALL_ROOT/bin/kt-run-module model-loader ${MODULE_VERSION}"
