#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
ARCH="$(uname -m)"
DEFAULT_RUNTIME="osx-arm64"
if [[ "$ARCH" == "x86_64" ]]; then
  DEFAULT_RUNTIME="osx-x64"
fi

SOURCE_PATH="${1:-$ROOT_DIR/publish/$DEFAULT_RUNTIME}"
INSTALL_DIR="/usr/local/localapi"
PLIST_TARGET="/Library/LaunchDaemons/com.mycompany.localapi.plist"
PORT="${LOCALAPI_PORT:-5099}"
DB_PROVIDER="${LOCALAPI_DB_PROVIDER:-Sqlite}"
INSTALL_DB_SERVER="${LOCALAPI_INSTALL_DB_SERVER:-false}"

if [[ $EUID -ne 0 ]]; then
  echo "Bu script sudo ile calistirilmali." >&2
  exit 1
fi

if [[ ! -d "$SOURCE_PATH" ]]; then
  echo "Publish klasoru bulunamadi: $SOURCE_PATH" >&2
  exit 1
fi

command_exists() { command -v "$1" >/dev/null 2>&1; }

ensure_homebrew() {
  if command_exists brew; then
    return 0
  fi
  echo "Homebrew bulunamadi. Once Homebrew kurulmalı: https://brew.sh"
  return 1
}

ensure_dotnet_runtime_if_needed() {
  if [[ -f "$SOURCE_PATH/LocalApi" ]]; then
    echo "Self-contained publish tespit edildi; runtime kurulumu atlaniyor."
    return 0
  fi

  if command_exists dotnet; then
    return 0
  fi

  if ensure_homebrew; then
    brew install --cask dotnet-sdk
  fi
}

ensure_db_server_if_requested() {
  if [[ "$INSTALL_DB_SERVER" != "true" ]]; then
    return 0
  fi

  if ! ensure_homebrew; then
    return 0
  fi

  case "$DB_PROVIDER" in
    SqlServer)
      echo "SQL Server macOS native server desteklemedigi icin otomatik kurulum yok. Docker onerilir."
      ;;
    PostgreSql)
      brew install postgresql@16 || true
      brew services start postgresql@16 || true
      ;;
    Sqlite)
      brew install sqlite || true
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

# Always rewrite production config to avoid stale/invalid DatabaseProvider values.
write_production_config

(
  cd "$INSTALL_DIR"
  ASPNETCORE_ENVIRONMENT=Production ASPNETCORE_URLS="http://0.0.0.0:$PORT" ./LocalApi --migrate
)

cat > "$PLIST_TARGET" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.mycompany.localapi</string>
  <key>ProgramArguments</key>
  <array>
    <string>$INSTALL_DIR/LocalApi</string>
    <string>--urls</string>
    <string>http://0.0.0.0:$PORT</string>
  </array>
  <key>WorkingDirectory</key>
  <string>$INSTALL_DIR</string>
  <key>EnvironmentVariables</key>
  <dict>
    <key>ASPNETCORE_ENVIRONMENT</key>
    <string>Production</string>
    <key>ASPNETCORE_URLS</key>
    <string>http://0.0.0.0:$PORT</string>
  </dict>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <true/>
  <key>StandardOutPath</key>
  <string>/usr/local/localapi/localapi.out.log</string>
  <key>StandardErrorPath</key>
  <string>/usr/local/localapi/localapi.err.log</string>
</dict>
</plist>
PLIST

launchctl bootout system "$PLIST_TARGET" 2>/dev/null || true
launchctl bootstrap system "$PLIST_TARGET"
launchctl enable system/com.mycompany.localapi

echo "Kurulum tamamlandi."
