#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
UNINSTALL_SCRIPT="$SCRIPT_DIR/uninstall.sh"

echo "[STEP] Uninstall baslatiliyor..."
if [[ $EUID -ne 0 ]]; then
  exec sudo bash "$UNINSTALL_SCRIPT"
else
  bash "$UNINSTALL_SCRIPT"
fi
