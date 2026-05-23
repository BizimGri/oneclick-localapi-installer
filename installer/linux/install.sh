#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
ARCH="$(uname -m)"
DEFAULT_RUNTIME="linux-x64"
if [[ "$ARCH" == "aarch64" || "$ARCH" == "arm64" ]]; then
  DEFAULT_RUNTIME="linux-arm64"
fi

SOURCE_PATH="${1:-$ROOT_DIR/publish/$DEFAULT_RUNTIME}"
INSTALL_DIR="/opt/localapi"
SERVICE_FILE="/etc/systemd/system/localapi.service"
PORT="${LOCALAPI_PORT:-5099}"
DB_PROVIDER="${LOCALAPI_DB_PROVIDER:-Sqlite}"
INSTALL_DB_SERVER="${LOCALAPI_INSTALL_DB_SERVER:-false}"

if [[ $EUID -ne 0 ]]; then
  echo "Bu script root ile calistirilmali." >&2
  exit 1
fi

if [[ ! -d "$SOURCE_PATH" ]]; then
  echo "Publish klasoru bulunamadi: $SOURCE_PATH" >&2
  exit 1
fi

command_exists() { command -v "$1" >/dev/null 2>&1; }

install_pkg() {
  if command_exists apt-get; then
    apt-get update
    apt-get install -y "$@"
  elif command_exists dnf; then
    dnf install -y "$@"
  elif command_exists yum; then
    yum install -y "$@"
  elif command_exists zypper; then
    zypper --non-interactive install "$@"
  else
    echo "Desteklenmeyen paket yoneticisi. Manuel kurulum gerekli: $*" >&2
    return 1
  fi
}

ensure_dotnet_runtime_if_needed() {
  if [[ -f "$SOURCE_PATH/LocalApi" ]]; then
    echo "Self-contained publish tespit edildi; runtime kurulumu atlaniyor."
    return 0
  fi

  if command_exists dotnet; then
    echo "dotnet bulundu."
    return 0
  fi

  echo "dotnet runtime kuruluyor..."
  install_pkg dotnet-runtime-8.0 || echo "dotnet-runtime-8.0 otomatik kurulamadi; manuel kurulum gerekebilir."
}

ensure_db_server_if_requested() {
  if [[ "$INSTALL_DB_SERVER" != "true" ]]; then
    return 0
  fi

  case "$DB_PROVIDER" in
    SqlServer)
      echo "SQL Server Linux kurulumu dagitima gore degisir; otomatik adim atlaniyor."
      ;;
    PostgreSql)
      if ! command_exists psql; then
        install_pkg postgresql postgresql-server || echo "PostgreSQL otomatik kurulamadi."
      fi
      ;;
    Sqlite)
      install_pkg sqlite3 || true
      ;;
  esac
}

write_production_config() {
cat > "$INSTALL_DIR/appsettings.Production.json" <<JSON
{
  "DatabaseProvider": "$DB_PROVIDER",
  "ConnectionStrings": {
    "SqlServer": "Server=localhost,1433;Database=LocalApiDb;User Id=sa;Password=YourStrong!Passw0rd;TrustServerCertificate=True;",
    "PostgreSql": "Host=localhost;Port=5432;Database=localapidb;Username=postgres;Password=postgres;",
    "Sqlite": "Data Source=$INSTALL_DIR/localapi.db"
  },
  "Logging": {
    "LogLevel": {
      "Default": "Information",
      "Microsoft.AspNetCore": "Warning"
    }
  },
  "AllowedHosts": "*"
}
JSON
}

mkdir -p "$INSTALL_DIR"
cp -R "$SOURCE_PATH"/* "$INSTALL_DIR"/
chmod +x "$INSTALL_DIR/LocalApi" || true

ensure_dotnet_runtime_if_needed
ensure_db_server_if_requested
write_production_config

cat > /etc/default/localapi <<ENV
ASPNETCORE_ENVIRONMENT=Production
ASPNETCORE_URLS=http://0.0.0.0:$PORT
ENV

(
  cd "$INSTALL_DIR"
  ASPNETCORE_ENVIRONMENT=Production ASPNETCORE_URLS="http://0.0.0.0:$PORT" ./LocalApi --migrate
)

cat > "$SERVICE_FILE" <<SERVICE
[Unit]
Description=LocalApi Service
After=network.target

[Service]
Type=simple
WorkingDirectory=$INSTALL_DIR
ExecStart=$INSTALL_DIR/LocalApi --urls http://0.0.0.0:$PORT
Restart=always
RestartSec=5
EnvironmentFile=/etc/default/localapi
User=root

[Install]
WantedBy=multi-user.target
SERVICE

systemctl daemon-reload
systemctl enable localapi.service
systemctl restart localapi.service

echo "Kurulum tamamlandi."
