#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

REPO_URL="${1:-https://github.com/BizimGri/oneclick-localapi-installer.git}"
TARGET_DIR="${2:-$SCRIPT_DIR/oneclick-localapi-installer}"

command_exists() { command -v "$1" >/dev/null 2>&1; }

install_git_linux() {
  if command_exists apt-get; then
    apt-get update
    apt-get install -y git
  elif command_exists dnf; then
    dnf install -y git
  elif command_exists yum; then
    yum install -y git
  elif command_exists zypper; then
    zypper --non-interactive install git
  else
    return 1
  fi
}

ensure_git() {
  if command_exists git; then
    return 0
  fi

  uname_s="$(uname -s)"
  case "$uname_s" in
    Linux)
      if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
        echo "git kurulumu icin sudo gerekiyor. Script sudo ile yeniden baslatiliyor..."
        exec sudo -E bash "$0" "$REPO_URL" "$TARGET_DIR"
      fi
      install_git_linux || {
        echo "git otomatik kurulamadı. Manuel kurulum gerekli." >&2
        return 1
      }
      ;;
    Darwin)
      if command_exists brew; then
        brew install git
      else
        echo "git bulunamadi. macOS icin once Command Line Tools veya Homebrew kurun." >&2
        return 1
      fi
      ;;
    *)
      echo "Desteklenmeyen platform: $uname_s" >&2
      return 1
      ;;
  esac

  command_exists git
}

ensure_git || {
  echo "git hazir degil. Kurulum durduruldu." >&2
  exit 1
}

if [[ -d "$TARGET_DIR/.git" ]]; then
  echo "[STEP] Repo guncelleniyor: $TARGET_DIR"
  git -C "$TARGET_DIR" pull --ff-only
else
  echo "[STEP] Repo klonlaniyor: $REPO_URL -> $TARGET_DIR"
  git clone "$REPO_URL" "$TARGET_DIR"
fi

cd "$TARGET_DIR"

uname_s="$(uname -s)"
case "$uname_s" in
  Linux)
    chmod +x installer/linux/*.sh scripts/publish.sh
    if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
      exec sudo -E ./installer/linux/oneclick-install.sh
    fi
    exec ./installer/linux/oneclick-install.sh
    ;;
  Darwin)
    chmod +x installer/macos/*.sh scripts/publish.sh
    if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
      exec sudo -E ./installer/macos/oneclick-install.sh
    fi
    exec ./installer/macos/oneclick-install.sh
    ;;
  *)
    echo "Bu script yalnizca Linux/macOS icin tasarlandi. Windows icin bootstrap/install.ps1 kullanin." >&2
    exit 1
    ;;
esac
