#!/usr/bin/bash
# Inject Socreate Anaconda + branding into netinst install.img (squashfs).
set -euo pipefail

TOPDIR="${TOPDIR:-$(cd "$(dirname "$0")/../.." && pwd)}"
INSTALL_IMG="${1:-}"
WORKDIR="${WORKDIR:-$TOPDIR/work/install-img-root}"

if [[ -z "$INSTALL_IMG" || ! -f "$INSTALL_IMG" ]]; then
    echo "Usage: $0 /path/to/install.img" >&2
    exit 1
fi

pick_latest() {
    local pattern="$1"
    ls -1 $pattern 2>/dev/null | grep -vE 'debuginfo|devel' | sort -V | tail -1
}

ANACONDA_CORE="$(pick_latest "$TOPDIR/RPMS/"{x86_64,noarch}"/anaconda-core-"*.rpm)"
ANACONDA_GUI="$(pick_latest "$TOPDIR/RPMS/"{x86_64,noarch}"/anaconda-gui-"*.rpm)"
ANACONDA_TUI="$(pick_latest "$TOPDIR/RPMS/"{x86_64,noarch}"/anaconda-tui-"*.rpm)"
ANACONDA_WIDGETS="$(pick_latest "$TOPDIR/RPMS/"{x86_64,noarch}"/anaconda-widgets-"*.rpm)"
SOCREATE_LOGOS="$(pick_latest "$TOPDIR/RPMS/noarch/socreate-logos-"*.noarch.rpm)"
BUILDSTAMP="$TOPDIR/SOURCES/socreate.buildstamp"

for f in "$ANACONDA_CORE" "$ANACONDA_GUI" "$ANACONDA_TUI" "$ANACONDA_WIDGETS" "$SOCREATE_LOGOS"; do
    [[ -f "$f" ]] || { echo "Missing RPM: $f" >&2; exit 1; }
done

echo "==> Unpack install.img -> $WORKDIR"
rm -rf "$WORKDIR"
mkdir -p "$WORKDIR"
unsquashfs -f -d "$WORKDIR" "$INSTALL_IMG"

echo "==> Install Socreate Anaconda + logos into install.img root"
RPM_NOCHECK=1 rpm -Uvh \
    --root="$WORKDIR" \
    --replacepkgs --replacefiles \
    --noscripts --nodeps \
    "$ANACONDA_CORE" "$ANACONDA_GUI" "$ANACONDA_TUI" "$ANACONDA_WIDGETS" "$SOCREATE_LOGOS"

install -m 0644 "$BUILDSTAMP" "$WORKDIR/.buildstamp"

echo "==> Apply Socreate Anaconda profile (flexible disk, no 15 GiB cap)"
install -d -m 0755 "$WORKDIR/etc/anaconda/profile.d"
install -m 0644 "$TOPDIR/SOURCES/anaconda-profile-socreate.conf" \
    "$WORKDIR/etc/anaconda/profile.d/socreate.conf"

echo "==> Install Socreate Anaconda branding assets"
install -d -m 0755 "$WORKDIR/usr/share/anaconda/pixmaps/server"
install -m 0644 "$TOPDIR/SOURCES/socreate-logos/anaconda/server/socreate-server.css" \
    "$WORKDIR/usr/share/anaconda/pixmaps/server/socreate-server.css"
rm -f "$WORKDIR/usr/share/anaconda/pixmaps/server/fedora-server.css"
for asset in sidebar-logo.png sidebar-bg.png topbar-bg.png; do
    src="$(find "$TOPDIR/BUILD" -path "*/generated/anaconda/$asset" 2>/dev/null | head -1)"
    if [[ -f "$src" ]]; then
        install -m 0644 "$src" "$WORKDIR/usr/share/anaconda/pixmaps/server/$asset"
    fi
done
if [[ ! -f "$WORKDIR/usr/share/anaconda/pixmaps/server/sidebar-logo.png" ]]; then
    tmpdir="$(mktemp -d)"
    rpm2cpio "$SOCREATE_LOGOS" | (cd "$tmpdir" && cpio -idmv './usr/share/anaconda/pixmaps/server/'* 2>/dev/null)
    for asset in sidebar-logo.png sidebar-bg.png topbar-bg.png socreate-server.css; do
        [[ -f "$tmpdir/usr/share/anaconda/pixmaps/server/$asset" ]] && \
            install -m 0644 "$tmpdir/usr/share/anaconda/pixmaps/server/$asset" \
                "$WORKDIR/usr/share/anaconda/pixmaps/server/$asset"
    done
    rm -rf "$tmpdir"
fi

echo "==> Repack install.img"
TMP_IMG="$(mktemp /tmp/install.img.socreate.XXXXXX)"
rm -f "$INSTALL_IMG"
mksquashfs "$WORKDIR" "$TMP_IMG" -comp xz -Xdict-size 131072 -noappend -no-recovery
rm -rf "$WORKDIR"
mv -f "$TMP_IMG" "$INSTALL_IMG"
echo "==> Patched: $INSTALL_IMG"
