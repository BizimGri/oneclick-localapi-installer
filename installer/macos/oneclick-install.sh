#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
PUBLISH_SCRIPT="$ROOT_DIR/scripts/publish.sh"
INSTALL_SCRIPT="$SCRIPT_DIR/install.sh"

PORT="${LOCALAPI_PORT:-5099}"
DB_PROVIDER="${LOCALAPI_DB_PROVIDER:-Sqlite}"
INSTALL_DB_SERVER="${LOCALAPI_INSTALL_DB_SERVER:-false}"
SKIP_PUBLISH="false"
SOURCE_PATH=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-publish)
      SKIP_PUBLISH="true"
      shift
      ;;
    --source)
      SOURCE_PATH="$2"
      shift 2
      ;;
    --port)
      PORT="$2"
      shift 2
      ;;
    --db-provider)
      DB_PROVIDER="$2"
      shift 2
      ;;
    --install-db-server)
      INSTALL_DB_SERVER="true"
      shift
      ;;
    *)
      echo "Bilinmeyen parametre: $1" >&2
      exit 1
      ;;
  esac
done

if [[ "$SKIP_PUBLISH" != "true" ]]; then
  echo "[STEP] Publish baslatiliyor..."
  "$PUBLISH_SCRIPT"
fi

if [[ -z "$SOURCE_PATH" ]]; then
  arch="$(uname -m)"
  runtime="osx-arm64"
  if [[ "$arch" == "x86_64" ]]; then
    runtime="osx-x64"
  fi
  SOURCE_PATH="$ROOT_DIR/publish/$runtime"
fi

echo "[STEP] Install baslatiliyor..."
if [[ $EUID -ne 0 ]]; then
  exec sudo env \
    LOCALAPI_PORT="$PORT" \
    LOCALAPI_DB_PROVIDER="$DB_PROVIDER" \
    LOCALAPI_INSTALL_DB_SERVER="$INSTALL_DB_SERVER" \
    bash "$INSTALL_SCRIPT" "$SOURCE_PATH"
else
  LOCALAPI_PORT="$PORT" \
  LOCALAPI_DB_PROVIDER="$DB_PROVIDER" \
  LOCALAPI_INSTALL_DB_SERVER="$INSTALL_DB_SERVER" \
  bash "$INSTALL_SCRIPT" "$SOURCE_PATH"
fi

echo "[OK] Kurulum tamamlandi."
