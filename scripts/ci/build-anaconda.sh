#!/usr/bin/bash
# Build Socreate-patched Anaconda from Fedora 44 SRPM source (manual compile).
set -euo pipefail

TOPDIR="${TOPDIR:-$(cd "$(dirname "$0")/../.." && pwd)}"
cd "$TOPDIR"

FEDORA_VERSION="${FEDORA_VERSION:-44}"
ANACONDA_NEVR="${ANACONDA_NEVR:-44.30-2.fc44}"
SOCREATE_DIST="${SOCREATE_DIST:-.soc26h1q2}"
ANACONDA_SRPM="${ANACONDA_SRPM:-$TOPDIR/SOURCES/anaconda-${ANACONDA_NEVR}.src.rpm}"
ANACONDA_SPEC="$TOPDIR/SPECS/anaconda.spec"
FEDORA_MIRROR="${FEDORA_MIRROR:-https://dl.fedoraproject.org/pub/fedora/linux}"

mkdir -p "$TOPDIR"/{BUILD,BUILDROOT,RPMS,SOURCES,SPECS,SRPMS}

pick_latest() {
    local pattern="$1"
    ls -1 $pattern 2>/dev/null | sort -V | tail -1
}

RPMBUILD=(rpmbuild --define "_topdir $TOPDIR" --define "dist ${SOCREATE_DIST}" \
    --define "fedora ${FEDORA_VERSION}" --define "fc${FEDORA_VERSION} 1" \
    --without glade)

DNF_REPOS_TMP=""
cleanup() {
    [[ -n "$DNF_REPOS_TMP" ]] && rm -rf "$DNF_REPOS_TMP"
}
trap cleanup EXIT

setup_fedora_dnf() {
    DNF_REPOS_TMP="$(mktemp -d)"
    mkdir -p "$DNF_REPOS_TMP/yum.repos.d"
    cat > "$DNF_REPOS_TMP/yum.repos.d/fedora-anaconda.repo" <<EOF
[fedora]
name=Fedora ${FEDORA_VERSION} Everything
baseurl=${FEDORA_MIRROR}/releases/${FEDORA_VERSION}/Everything/\$basearch/os/
enabled=1
gpgcheck=0

[updates]
name=Fedora ${FEDORA_VERSION} Updates
baseurl=${FEDORA_MIRROR}/updates/${FEDORA_VERSION}/Everything/\$basearch/
enabled=1
gpgcheck=0
EOF
    DNF_FEDORA=(
        dnf -y --disablerepo='*'
        --enablerepo=fedora --enablerepo=updates
        --setopt=reposdir="$DNF_REPOS_TMP/yum.repos.d"
        --releasever="$FEDORA_VERSION"
    )
}

echo "==> Ensure socreate-logos RPM is built"
if [[ ! -f "$(pick_latest "$TOPDIR/RPMS/noarch/socreate-logos-*.noarch.rpm")" ]]; then
    bash "$TOPDIR/scripts/ci/build-release.sh"
fi

setup_fedora_dnf

if [[ ! -f "$ANACONDA_SRPM" ]]; then
    echo "==> Download anaconda SRPM: anaconda-${ANACONDA_NEVR}"
    ( cd "$TOPDIR/SOURCES" && "${DNF_FEDORA[@]}" download --source "anaconda-${ANACONDA_NEVR}" )
    mv -f "$TOPDIR/SOURCES/anaconda-${ANACONDA_NEVR}.src.rpm" "$ANACONDA_SRPM" 2>/dev/null || true
fi

if [[ ! -f "$ANACONDA_SRPM" ]]; then
    echo "ERROR: anaconda SRPM not found: $ANACONDA_SRPM" >&2
    exit 1
fi

if [[ ! -f "$ANACONDA_SPEC" ]]; then
    echo "==> Install anaconda SRPM into rpmbuild tree"
    rpm -Uvh "$ANACONDA_SRPM"
fi

ANACONDA_TARBALL="$(rpm -qpl "$ANACONDA_SRPM" | grep -E 'anaconda-.*\.tar\.(bz2|gz)$' | head -1 | xargs basename)"
PATCH6767="$(rpm -qpl "$ANACONDA_SRPM" | grep -E '\.patch$' | head -1 | xargs basename)"

if [[ -z "$ANACONDA_TARBALL" || -z "$PATCH6767" ]]; then
    echo "ERROR: could not detect anaconda source tarball/patch in SRPM" >&2
    exit 1
fi

if [[ ! -f "$TOPDIR/SOURCES/$ANACONDA_TARBALL" || ! -f "$TOPDIR/SOURCES/$PATCH6767" ]]; then
    echo "==> Extract sources from anaconda SRPM"
    tmpdir="$(mktemp -d)"
    ( cd "$tmpdir" && rpm2cpio "$ANACONDA_SRPM" | cpio -idmv )
    install -m 0644 "$tmpdir/$ANACONDA_TARBALL" "$TOPDIR/SOURCES/$ANACONDA_TARBALL"
    install -m 0644 "$tmpdir/$PATCH6767" "$TOPDIR/SOURCES/$PATCH6767"
    rm -rf "$tmpdir"
fi

echo "==> Install Anaconda build dependencies (Fedora ${FEDORA_VERSION})"
if ! "${DNF_FEDORA[@]}" builddep -y "$ANACONDA_SPEC"; then
    "${DNF_FEDORA[@]}" install -y \
        libtool gettext-devel gtk3-devel gtk-doc gtk3-devel-docs glib2-doc \
        gobject-introspection-devel make pango-devel python3-devel systemd-rpm-macros \
        rpm-devel libarchive-devel gdk-pixbuf2-devel libxml2 \
        gsettings-desktop-schemas glib2-devel
fi

echo "==> Compile Socreate Anaconda RPMs (patched source, rpmbuild -ba)"
"${RPMBUILD[@]}" -ba "$ANACONDA_SPEC"

echo "==> Output:"
ls -lh "$TOPDIR/RPMS/"{x86_64,noarch}/anaconda-core-"*.rpm \
       "$TOPDIR/RPMS/"{x86_64,noarch}/anaconda-gui-"*.rpm \
       "$TOPDIR/RPMS/"{x86_64,noarch}/anaconda-tui-"*.rpm \
       "$TOPDIR/RPMS/"{x86_64,noarch}/anaconda-widgets-"*.rpm 2>/dev/null
