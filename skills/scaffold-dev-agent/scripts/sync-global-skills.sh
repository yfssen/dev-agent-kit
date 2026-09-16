#!/usr/bin/env bash
# Sync scaffold-dev-agent into each AI tool global skills dir.
# Usage: ./sync-global-skills.sh [kit-root]

set -eu
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
if [ "${1:-}" != "" ]; then
  KIT=$(CDPATH= cd -- "$1" && pwd)
else
  KIT=$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)
fi

exec "$KIT/install-global.sh" "$KIT"
