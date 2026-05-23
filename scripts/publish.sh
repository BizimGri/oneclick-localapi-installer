#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT="$ROOT_DIR/src/LocalApi/LocalApi.csproj"
OUT_BASE="$ROOT_DIR/publish"

command_exists() { command -v "$1" >/dev/null 2>&1; }

install_dotnet_sdk_linux() {
  if command_exists apt-get; then
    if [[ ! -f /etc/apt/sources.list.d/microsoft-prod.list ]]; then
      . /etc/os-release
      apt-get update
      apt-get install -y wget gpg
      wget -q "https://packages.microsoft.com/config/${ID}/${VERSION_ID}/packages-microsoft-prod.deb" -O /tmp/packages-microsoft-prod.deb
      dpkg -i /tmp/packages-microsoft-prod.deb
      rm -f /tmp/packages-microsoft-prod.deb
    fi
    apt-get update
    apt-get install -y dotnet-sdk-8.0
  elif command_exists dnf; then
    dnf install -y dotnet-sdk-8.0
  elif command_exists yum; then
    yum install -y dotnet-sdk-8.0
  elif command_exists zypper; then
    zypper --non-interactive install dotnet-sdk-8.0
  else
    return 1
  fi
}

ensure_dotnet_sdk() {
  if command_exists dotnet; then
    return 0
  fi

  echo "dotnet bulunamadi. Otomatik kurulum deneniyor..."
  uname_s="$(uname -s)"

  if [[ "$uname_s" == "Darwin" ]]; then
    if command_exists brew; then
      brew install --cask dotnet-sdk
    else
      echo "Homebrew bulunamadi. Manuel kurulum: https://dotnet.microsoft.com/download" >&2
      return 1
    fi
  elif [[ "$uname_s" == "Linux" ]]; then
    if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
      echo "Linux'ta SDK kurulumu icin sudo gerekiyor. Otomatik olarak sudo ile yeniden calistiriliyor..."
      exec sudo -E bash "$0"
    fi
    install_dotnet_sdk_linux || {
      echo "dotnet SDK otomatik kurulamadi. Manuel kurulum: https://learn.microsoft.com/dotnet/core/install/linux" >&2
      return 1
    }
  else
    echo "Desteklenmeyen platform: $uname_s" >&2
    return 1
  fi

  command_exists dotnet
}

get_current_runtime() {
  local os arch
  os="$(uname -s)"
  arch="$(uname -m)"

  case "$os" in
    Linux)
      case "$arch" in
        x86_64|amd64) echo "linux-x64" ;;
        aarch64|arm64) echo "linux-arm64" ;;
        *) return 1 ;;
      esac
      ;;
    Darwin)
      case "$arch" in
        x86_64) echo "osx-x64" ;;
        arm64) echo "osx-arm64" ;;
        *) return 1 ;;
      esac
      ;;
    *) return 1 ;;
  esac
}

ensure_dotnet_sdk || {
  echo "dotnet SDK hazir degil. Publish durduruldu." >&2
  exit 1
}

if [[ ! -f "$PROJECT" ]]; then
  echo "Proje dosyasi bulunamadi: $PROJECT" >&2
  exit 1
fi

runtime="$(get_current_runtime)" || {
  echo "Mevcut sistem icin runtime tespit edilemedi." >&2
  exit 1
}

out_dir="$OUT_BASE/$runtime"
echo "Publishing $runtime -> $out_dir"
dotnet publish "$PROJECT" -c Release -r "$runtime" --self-contained true -o "$out_dir"

echo "Publish tamamlandi."
