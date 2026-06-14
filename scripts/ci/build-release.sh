#!/usr/bin/bash
set -euo pipefail

TOPDIR="${TOPDIR:-$(cd "$(dirname "$0")/../.." && pwd)}"
cd "$TOPDIR"

mkdir -p "$TOPDIR"/{BUILD,BUILDROOT,RPMS,SOURCES,SPECS,SRPMS}

LOGOS_VERSION="1.3"
LOGOS_TARBALL="$TOPDIR/SOURCES/socreate-logos-${LOGOS_VERSION}.tar.gz"
if [[ ! -f "$LOGOS_TARBALL" ]] || [[ "$TOPDIR/SOURCES/socreate-logos" -nt "$LOGOS_TARBALL" ]]; then
    echo "==> Packaging socreate-logos sources (${LOGOS_VERSION})"
    tar -C "$TOPDIR/SOURCES" -czf "$LOGOS_TARBALL" socreate-logos
fi

echo "==> Building socreate-logos RPM (topdir=$TOPDIR)"
rpmbuild -ba --define "_topdir $TOPDIR" SPECS/socreate-logos.spec

echo "==> Building socreate-release RPMs (topdir=$TOPDIR)"
rpmbuild -ba --define "_topdir $TOPDIR" SPECS/socreate-release.spec

echo "==> Building socreate-comps RPM (topdir=$TOPDIR)"
rpmbuild -ba --define "_topdir $TOPDIR" SPECS/socreate-comps.spec

echo "==> Building socreate-desktop RPMs (topdir=$TOPDIR)"
rpmbuild -ba --define "_topdir $TOPDIR" SPECS/socreate-desktop.spec

echo "==> Output:"
ls -lh RPMS/noarch/socreate-*.rpm SRPMS/socreate-*.src.rpm
