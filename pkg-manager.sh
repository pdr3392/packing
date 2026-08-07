#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
PACKAGE_MANAGER_BIN="$SCRIPT_DIR/bin/package-manager"

if [[ ! -x "$PACKAGE_MANAGER_BIN" ]]; then
    printf 'gen-manager: executable not found: %s\n' "$PACKAGE_MANAGER_BIN" >&2
    exit 1
fi

exec "$PACKAGE_MANAGER_BIN" "$@"
