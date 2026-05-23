#!/usr/bin/env bash
set -euo pipefail

INSTALL_DIR="/usr/local/localapi"
PLIST_TARGET="/Library/LaunchDaemons/com.mycompany.localapi.plist"

if [[ $EUID -ne 0 ]]; then
  echo "Bu script sudo ile çalıştırılmalı." >&2
  exit 1
fi

launchctl bootout system "$PLIST_TARGET" 2>/dev/null || true
launchctl disable system/com.mycompany.localapi 2>/dev/null || true
rm -f "$PLIST_TARGET"
rm -rf "$INSTALL_DIR"

echo "Kaldırma tamamlandı."
