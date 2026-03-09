#!/bin/sh

set -eu

INSTALL_PATH="${CODEX_INSTALL_PATH:-}"
SKIP_BACKUP=0
SKIP_BUILD="${CODEX_SKIP_BUILD:-0}"
SKIP_PLATFORM_CHECK="${CODEX_SKIP_PLATFORM_CHECK:-0}"
SOURCE_BIN_OVERRIDE="${CODEX_SOURCE_BIN:-}"

usage() {
  cat <<'EOF'
Usage: scripts/install/install-source.sh [--install-path PATH] [--skip-backup]

Build the current repository's Rust CLI, back up the existing global codex binary,
and install the freshly built binary to a global path on macOS or Linux.

Options:
  --install-path PATH  Override the destination path. Default: existing `codex`
                       binary target, or /usr/local/bin/codex when none exists.
  --skip-backup        Do not create a timestamped backup before installing.
  -h, --help           Show this help text.

Environment:
  CODEX_INSTALL_PATH   Same as --install-path.
  CODEX_SKIP_BUILD=1   Skip `cargo build` and use CODEX_SOURCE_BIN instead.
  CODEX_SKIP_PLATFORM_CHECK=1  Skip macOS/Linux checks. Intended for testing only.
  CODEX_SOURCE_BIN     Path to a prebuilt codex binary. Useful with CODEX_SKIP_BUILD=1.
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --install-path)
      if [ "$#" -lt 2 ]; then
        echo "--install-path requires a value" >&2
        exit 1
      fi
      INSTALL_PATH="$2"
      shift 2
      ;;
    --skip-backup)
      SKIP_BACKUP=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

step() {
  printf '==> %s\n' "$1"
}

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "$1 is required" >&2
    exit 1
  fi
}

ensure_cargo() {
  if command -v cargo >/dev/null 2>&1; then
    return
  fi

  if [ -x "$HOME/.cargo/bin/cargo" ]; then
    PATH="$HOME/.cargo/bin:$PATH"
    export PATH
    return
  fi

  require_command curl
  require_command mktemp
  step "Installing Rust toolchain with rustup"
  rustup_script="$(mktemp)"
  cleanup_rustup() {
    rm -f "$rustup_script"
  }
  trap cleanup_rustup EXIT INT TERM HUP
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs -o "$rustup_script"
  sh "$rustup_script" -s -- -y
  cleanup_rustup
  trap - EXIT INT TERM HUP
  PATH="$HOME/.cargo/bin:$PATH"
  export PATH
}

resolve_target_path() {
  if [ -n "$INSTALL_PATH" ]; then
    printf '%s\n' "$INSTALL_PATH"
    return
  fi

  if command -v codex >/dev/null 2>&1; then
    existing="$(command -v codex)"
    if command -v readlink >/dev/null 2>&1; then
      resolved="$(readlink -f "$existing" 2>/dev/null || true)"
      if [ -n "$resolved" ]; then
        printf '%s\n' "$resolved"
        return
      fi
    fi
    printf '%s\n' "$existing"
    return
  fi

  printf '/usr/local/bin/codex\n'
}

needs_sudo_for_path() {
  target="$1"
  target_dir="$(dirname "$target")"

  if [ -e "$target" ]; then
    [ -w "$target" ] || return 0
    return 1
  fi

  while [ ! -d "$target_dir" ]; do
    parent="$(dirname "$target_dir")"
    if [ "$parent" = "$target_dir" ]; then
      break
    fi
    target_dir="$parent"
  done

  [ -w "$target_dir" ] || return 0
  return 1
}

copy_with_optional_sudo() {
  if [ "$USE_SUDO" -eq 1 ]; then
    sudo "$@"
  else
    "$@"
  fi
}

if [ "$SKIP_PLATFORM_CHECK" -ne 1 ]; then
  case "$(uname -s)" in
    Darwin) ;;
    Linux)
      if [ -r /etc/os-release ]; then
        # shellcheck disable=SC1091
        . /etc/os-release
        case "${ID:-}" in
          ubuntu|debian) ;;
          *)
            echo "Warning: this script was originally written for Ubuntu/Debian-style Linux, detected ${ID:-unknown}." >&2
            ;;
        esac
      fi
      ;;
    *)
      echo "This installer supports macOS and Linux." >&2
      exit 1
      ;;
  esac
fi

require_command git
require_command install
require_command cp
require_command date

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)
WORKSPACE_DIR="$REPO_ROOT/codex-rs"

if [ ! -f "$WORKSPACE_DIR/Cargo.toml" ]; then
  echo "Could not find codex-rs/Cargo.toml under $REPO_ROOT" >&2
  exit 1
fi

TARGET_PATH="$(resolve_target_path)"
TARGET_DIR="$(dirname "$TARGET_PATH")"
BACKUP_PATH="${TARGET_PATH}.bak.$(date +%Y%m%d-%H%M%S)"
USE_SUDO=0

if needs_sudo_for_path "$TARGET_PATH"; then
  USE_SUDO=1
  require_command sudo
fi

SOURCE_BIN="$WORKSPACE_DIR/target/release/codex"
if [ "$SKIP_BUILD" -eq 1 ]; then
  if [ -z "$SOURCE_BIN_OVERRIDE" ]; then
    echo "CODEX_SKIP_BUILD=1 requires CODEX_SOURCE_BIN to be set" >&2
    exit 1
  fi
  SOURCE_BIN="$SOURCE_BIN_OVERRIDE"
  step "Skipping build and using prebuilt binary at $SOURCE_BIN"
else
  ensure_cargo
  step "Building codex-cli from source"
  (
    cd "$WORKSPACE_DIR"
    cargo build -p codex-cli --release
  )
fi

if [ ! -x "$SOURCE_BIN" ]; then
  echo "Build completed but $SOURCE_BIN was not found" >&2
  exit 1
fi

copy_with_optional_sudo mkdir -p "$TARGET_DIR"

if [ -e "$TARGET_PATH" ] && [ "$SKIP_BACKUP" -eq 0 ]; then
  step "Backing up existing codex to $BACKUP_PATH"
  copy_with_optional_sudo cp "$TARGET_PATH" "$BACKUP_PATH"
fi

step "Installing codex to $TARGET_PATH"
copy_with_optional_sudo install -m 755 "$SOURCE_BIN" "$TARGET_PATH"

step "Installed successfully"
printf 'Run: %s --version\n' "$TARGET_PATH"
