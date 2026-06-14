#!/usr/bin/bash
set -euo pipefail
TOPDIR="$(cd "$(dirname "$0")/../.." && pwd)"
exec "$TOPDIR/SOURCES/apply-anaconda-socreate.sh" "$@"
