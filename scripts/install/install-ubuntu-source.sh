#!/bin/sh

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

echo "scripts/install/install-ubuntu-source.sh is deprecated; use scripts/install/install-source.sh" >&2
exec "$SCRIPT_DIR/install-source.sh" "$@"
