#!/usr/bin/bash
set -euo pipefail

TOPDIR="${TOPDIR:-$(cd "$(dirname "$0")/../.." && pwd)}"
cd "$TOPDIR"

mkdir -p "$TOPDIR"/{BUILD,BUILDROOT,RPMS,SOURCES,SPECS,SRPMS}

echo "==> Building socreate-release RPMs (topdir=$TOPDIR)"
rpmbuild -ba --define "_topdir $TOPDIR" SPECS/socreate-release.spec

echo "==> Output:"
ls -lh RPMS/noarch/socreate-*.rpm SRPMS/socreate-release-*.src.rpm
