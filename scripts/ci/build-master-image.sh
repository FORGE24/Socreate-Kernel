#!/usr/bin/bash
# CI entry: build Socreate golden master QCOW2 from kickstart + local RPM repo.
set -euo pipefail

TOPDIR="${TOPDIR:-$(cd "$(dirname "$0")/../.." && pwd)}"
cd "$TOPDIR"

BUILD_ISO="${BUILD_ISO:-0}"
IMAGE_MODE="${IMAGE_MODE:-lmc}"

if [[ "$BUILD_ISO" == "1" ]]; then
    bash "$TOPDIR/scripts/ci/package-local-install.sh"
fi

bash "$TOPDIR/scripts/imaging/create-master-image.sh" "$IMAGE_MODE"
