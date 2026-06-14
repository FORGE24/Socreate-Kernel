#!/usr/bin/bash
# Build Socreate-patched Anaconda from Fedora 44 SRPM source (manual compile).
set -euo pipefail

TOPDIR="${TOPDIR:-$(cd "$(dirname "$0")/../.." && pwd)}"
cd "$TOPDIR"

FEDORA_VERSION="${FEDORA_VERSION:-44}"
ANACONDA_NEVR="${ANACONDA_NEVR:-44.30-2.fc44}"
SOCREATE_DIST="${SOCREATE_DIST:-.soc26h1q2}"
ANACONDA_SRPM="${ANACONDA_SRPM:-$TOPDIR/SOURCES/anaconda-${ANACONDA_NEVR}.src.rpm}"
ANACONDA_TARBALL="$TOPDIR/SOURCES/anaconda-44.30.tar.bz2"
PATCH6767="$TOPDIR/SOURCES/6767.patch"
ANACONDA_SPEC="$TOPDIR/SPECS/anaconda.spec"

mkdir -p "$TOPDIR"/{BUILD,BUILDROOT,RPMS,SOURCES,SPECS,SRPMS}

pick_latest() {
    local pattern="$1"
    ls -1 $pattern 2>/dev/null | sort -V | tail -1
}

RPMBUILD=(rpmbuild --define "_topdir $TOPDIR" --define "dist ${SOCREATE_DIST}" \
    --define "fedora ${FEDORA_VERSION}" --define "fc${FEDORA_VERSION} 1" \
    --without glade)

echo "==> Ensure socreate-logos RPM is built"
if [[ ! -f "$(pick_latest "$TOPDIR/RPMS/noarch/socreate-logos-*.noarch.rpm")" ]]; then
    bash "$TOPDIR/scripts/ci/build-release.sh"
fi

if [[ ! -f "$ANACONDA_SRPM" ]]; then
    echo "==> Download anaconda SRPM: anaconda-${ANACONDA_NEVR}"
    ( cd "$TOPDIR/SOURCES" && dnf download --source "anaconda-${ANACONDA_NEVR}" \
        --releasever="$FEDORA_VERSION" --disablerepo='socreate*' --enablerepo=fedora -y )
fi

if [[ ! -f "$ANACONDA_TARBALL" || ! -f "$PATCH6767" ]]; then
    echo "==> Extract sources from anaconda SRPM"
    tmpdir="$(mktemp -d)"
    ( cd "$tmpdir" && rpm2cpio "$ANACONDA_SRPM" | cpio -idmv )
    install -m 0644 "$tmpdir/anaconda-44.30.tar.bz2" "$ANACONDA_TARBALL"
    install -m 0644 "$tmpdir/6767.patch" "$PATCH6767"
    rm -rf "$tmpdir"
fi

if [[ ! -f "$ANACONDA_SPEC" ]]; then
    rpm -ivh "$ANACONDA_SRPM"
fi

echo "==> Install Anaconda build dependencies (Fedora ${FEDORA_VERSION} repos)"
DNF_BUILD=(
    dnf --releasever="$FEDORA_VERSION"
    --disablerepo='socreate*'
    --enablerepo=fedora
    --enablerepo=updates
)
if ! "${DNF_BUILD[@]}" repolist --enabled 2>/dev/null | grep -qE 'fedora|updates'; then
    DNF_BUILD=(
        dnf --releasever="$FEDORA_VERSION"
        --disablerepo='*'
        --enablerepo='socreate-base,socreate-appstream,socreate-custom-appstream,socreate-updates'
    )
fi
"${DNF_BUILD[@]}" builddep -y "$ANACONDA_SPEC" || {
    "${DNF_BUILD[@]}" install -y \
        libtool gettext-devel gtk3-devel gtk-doc gtk3-devel-docs glib2-doc \
        gobject-introspection-devel make pango-devel python3-devel systemd-rpm-macros \
        rpm-devel libarchive-devel gdk-pixbuf2-devel libxml2 \
        gsettings-desktop-schemas glib2-devel
}

echo "==> Compile Socreate Anaconda RPMs (patched source, rpmbuild -ba)"
"${RPMBUILD[@]}" -ba "$ANACONDA_SPEC"

echo "==> Output:"
ls -lh "$TOPDIR/RPMS/"{x86_64,noarch}/anaconda-core-"*.rpm \
       "$TOPDIR/RPMS/"{x86_64,noarch}/anaconda-gui-"*.rpm \
       "$TOPDIR/RPMS/"{x86_64,noarch}/anaconda-tui-"*.rpm \
       "$TOPDIR/RPMS/"{x86_64,noarch}/anaconda-widgets-"*.rpm 2>/dev/null
