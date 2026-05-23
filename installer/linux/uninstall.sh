#!/usr/bin/env bash
set -euo pipefail

INSTALL_DIR="/opt/localapi"
SERVICE_FILE="/etc/systemd/system/localapi.service"

if [[ $EUID -ne 0 ]]; then
  echo "Bu script root ile çalıştırılmalı." >&2
  exit 1
fi

systemctl stop localapi.service 2>/dev/null || true
systemctl disable localapi.service 2>/dev/null || true
rm -f "$SERVICE_FILE"
rm -f /etc/default/localapi
systemctl daemon-reload

rm -rf "$INSTALL_DIR"

echo "Kaldırma tamamlandı."
