#!/usr/bin/bash
set -euo pipefail

TOPDIR="${TOPDIR:-$(cd "$(dirname "$0")/../.." && pwd)}"
cd "$TOPDIR"

echo "==> Building socreate-release RPMs"
rpmbuild -ba SPECS/socreate-release.spec

echo "==> Output:"
ls -lh RPMS/noarch/socreate-*.rpm SRPMS/socreate-release-*.src.rpm
