#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TARGET_DIR="${HOME}/Downloads/oneclick-localapi-installer"

rm -rf "$TARGET_DIR"
cp -R "$ROOT_DIR" "$TARGET_DIR"

echo "Synced: $TARGET_DIR"
