#!/usr/bin/bash
# Build and stage all Socreate mirror overlay files for upload to rope.sanrol-cloud.top.
set -euo pipefail

TOPDIR="${TOPDIR:-$(cd "$(dirname "$0")/../.." && pwd)}"
cd "$TOPDIR"

SYNC_BASE="${SYNC_BASE:-1}"
SKIP_STAGE="${SKIP_STAGE:-0}"
if [[ "$SKIP_STAGE" != "1" ]]; then
    bash "$TOPDIR/scripts/ci/stage-mirror-overlay.sh"
fi
if [[ "$SYNC_BASE" == "1" ]]; then
    bash "$TOPDIR/scripts/ci/sync-mirror-base-essentials.sh"
fi
bash "$TOPDIR/scripts/ci/finalize-mirror-upload.sh"
