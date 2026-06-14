#!/usr/bin/bash
# Stage Socreate mirror overlay files for upload to rope.sanrol-cloud.top.
# Produces dist/mirror-upload/<releasever>/ with:
#   x86_64/socreate kernel repo/  — kernel + Socreate branding (binary RPMs only)
#   x86_64/overlay/               — socreate-* RPMs to merge into the main repo
set -euo pipefail

TOPDIR="${TOPDIR:-$(cd "$(dirname "$0")/../.." && pwd)}"
cd "$TOPDIR"

MIRROR_DEFAULTS="$TOPDIR/SOURCES/socreate-mirror.defaults"
# shellcheck source=/dev/null
[[ -f "$MIRROR_DEFAULTS" ]] && source "$MIRROR_DEFAULTS"

RELEASEVER="${SOCREATE_RELEASEVER:-26H1Q2}"
ARCH="${SOCREATE_REPO_ARCH:-x86_64}"
KERNEL_REPO_DIRNAME="${SOCREATE_KERNEL_REPO_DIRNAME:-socreate kernel repo}"
COMPS_FILE="$TOPDIR/SOURCES/socreate-comps.xml"
STAGE_ROOT="$TOPDIR/dist/mirror-upload/${RELEASEVER}"
KERNEL_STAGE="$STAGE_ROOT/${ARCH}/${KERNEL_REPO_DIRNAME}"
OVERLAY_STAGE="$STAGE_ROOT/${ARCH}/overlay"
TARBALL="$TOPDIR/dist/socreate-${RELEASEVER}-mirror-overlay.tar.gz"

pick_latest() {
    local pattern="$1"
    local f
    f="$(ls -1 $pattern 2>/dev/null | sort -V | tail -1 || true)"
    if [[ -z "$f" ]]; then
        echo "Missing RPM matching: $pattern" >&2
        exit 1
    fi
    echo "$f"
}

copy_latest_noarch() {
    local pattern="$1"
    /bin/cp -f "$(pick_latest "$pattern")" "$2/"
}

echo "==> Build latest Socreate release RPMs"
if [[ "${SKIP_BUILD_RELEASE:-0}" != "1" ]]; then
    bash "$TOPDIR/scripts/ci/build-release.sh"
else
    echo "    SKIP_BUILD_RELEASE=1, using existing RPMS/"
fi

echo "==> Stage kernel repo: $KERNEL_STAGE"
rm -rf "$KERNEL_STAGE"
mkdir -p "$KERNEL_STAGE"

for pattern in \
    "$TOPDIR/RPMS/x86_64/kernel-[0-9]*.rpm" \
    "$TOPDIR/RPMS/x86_64/kernel-core-[0-9]*.rpm" \
    "$TOPDIR/RPMS/x86_64/kernel-modules-core-[0-9]*.rpm" \
    "$TOPDIR/RPMS/x86_64/kernel-modules-[0-9]*.rpm" \
    "$TOPDIR/RPMS/x86_64/kernel-devel-[0-9]*.rpm" \
    "$TOPDIR/RPMS/x86_64/kernel-modules-extra-[0-9]*.rpm" \
    "$TOPDIR/RPMS/x86_64/kernel-modules-internal-[0-9]*.rpm" \
    "$TOPDIR/RPMS/x86_64/kernel-uki-virt-[0-9]*.rpm" \
    "$TOPDIR/RPMS/x86_64/kernel-uki-virt-addons-[0-9]*.rpm"
do
    for rpm in $pattern; do
        [[ -f "$rpm" ]] || continue
        base="$(basename "$rpm")"
        [[ "$base" == *-matched-* ]] && continue
        /bin/cp -f "$rpm" "$KERNEL_STAGE/"
    done
done

copy_latest_noarch "$TOPDIR/RPMS/noarch/socreate-release-${RELEASEVER}-*.noarch.rpm" "$KERNEL_STAGE"
copy_latest_noarch "$TOPDIR/RPMS/noarch/socreate-repos-${RELEASEVER}-*.noarch.rpm" "$KERNEL_STAGE"
copy_latest_noarch "$TOPDIR/RPMS/noarch/socreate-logos-*.noarch.rpm" "$KERNEL_STAGE"

echo "==> Create kernel repo metadata (binary RPMs only)"
createrepo_c --quiet "$KERNEL_STAGE"

echo "==> Stage main-repo overlay: $OVERLAY_STAGE"
rm -rf "$OVERLAY_STAGE"
mkdir -p "$OVERLAY_STAGE"

copy_latest_noarch "$TOPDIR/RPMS/noarch/socreate-release-${RELEASEVER}-*.noarch.rpm" "$OVERLAY_STAGE"
copy_latest_noarch "$TOPDIR/RPMS/noarch/socreate-repos-${RELEASEVER}-*.noarch.rpm" "$OVERLAY_STAGE"
copy_latest_noarch "$TOPDIR/RPMS/noarch/socreate-logos-*.noarch.rpm" "$OVERLAY_STAGE"
for pattern in \
    "$TOPDIR/RPMS/noarch/socreate-comps-${RELEASEVER}-*.noarch.rpm" \
    "$TOPDIR/RPMS/noarch/socreate-desktop-${RELEASEVER}-*.noarch.rpm" \
    "$TOPDIR/RPMS/noarch/socreate-desktop-gnome-${RELEASEVER}-*.noarch.rpm" \
    "$TOPDIR/RPMS/noarch/socreate-desktop-kde-${RELEASEVER}-*.noarch.rpm" \
    "$TOPDIR/RPMS/noarch/socreate-release-gnome-${RELEASEVER}-*.noarch.rpm" \
    "$TOPDIR/RPMS/noarch/socreate-release-kde-${RELEASEVER}-*.noarch.rpm"
do
    for rpm in $pattern; do
        [[ -f "$rpm" ]] || continue
        /bin/cp -f "$rpm" "$OVERLAY_STAGE/"
    done
done

echo "==> Create overlay repo metadata (with comps for GUI environments)"
createrepo_c --quiet ${COMPS_FILE:+--groupfile "$COMPS_FILE"} "$OVERLAY_STAGE"

echo "==> Copy SRPMs (reference only, not indexed in repodata)"
SRPM_STAGE="$STAGE_ROOT/source"
mkdir -p "$SRPM_STAGE"
/bin/cp -f "$TOPDIR/SRPMS"/socreate-*.src.rpm "$SRPM_STAGE/" 2>/dev/null || true
/bin/cp -f "$TOPDIR/SRPMS"/anaconda-*.src.rpm "$SRPM_STAGE/" 2>/dev/null || true

echo "==> Staged mirror overlay (run finalize-mirror-upload.sh for tarball)"
find "$STAGE_ROOT" -maxdepth 4 -type f \( -name '*.rpm' -o -name 'repomd.xml' \) | sort | tail -20
