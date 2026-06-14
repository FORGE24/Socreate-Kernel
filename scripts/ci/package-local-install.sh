#!/usr/bin/bash
# Package Socreate OS local install media:
#   1) tarball with kickstart + local RPM repo (with comps for desktop groups)
#   2) optional bootable ISO (netinst base + Socreate overlay)
set -euo pipefail

TOPDIR="${TOPDIR:-$(cd "$(dirname "$0")/../.." && pwd)}"
cd "$TOPDIR"

RELEASEVER="${SOCREATE_RELEASEVER:-26H1Q2}"
SOCREATE_KS_API="${SOCREATE_KS_API:-44}"
NETINST_ISO="${NETINST_ISO:-socreate-netinst-x86_64-${RELEASEVER}-base.iso}"
NETINST_URL="${SOCREATE_NETINST_URL:-}"
NETINST_FALLBACK="${NETINST_FALLBACK:-$TOPDIR/dist/Fedora-Server-netinst-x86_64-${SOCREATE_KS_API}-1.7.iso}"
BUILD_ISO="${BUILD_ISO:-1}"
BUILD_ANACONDA="${BUILD_ANACONDA:-1}"
PATCH_INSTALL_IMG="${PATCH_INSTALL_IMG:-1}"

STAGE_DIR="$TOPDIR/dist/socreate-${RELEASEVER}-local"
REPO_DIR="$STAGE_DIR/socreate"
KS_DIR="$STAGE_DIR/kickstart"
DIST_DIR="$TOPDIR/dist"
TARBALL="$DIST_DIR/socreate-${RELEASEVER}-local-install.tar.gz"
ISO_OUT="$DIST_DIR/socreate-${RELEASEVER}-netinst.iso"
NETINST_CACHE="$DIST_DIR/${NETINST_ISO}"
COMPS_FILE="$TOPDIR/SOURCES/socreate-comps.xml"
MIRROR_DEFAULTS="$TOPDIR/SOURCES/socreate-mirror.defaults"

# shellcheck source=/dev/null
[[ -f "$MIRROR_DEFAULTS" ]] && source "$MIRROR_DEFAULTS"
SOCREATE_MIRROR_BASE="${SOCREATE_MIRROR_BASE:-http://rope.sanrol-cloud.top}"
SOCREATE_RELEASEVER="${SOCREATE_RELEASEVER:-26H1Q2}"
SOCREATE_REPO_ARCH="${SOCREATE_REPO_ARCH:-x86_64}"
SOCREATE_NETINST_URL="${SOCREATE_NETINST_URL:-${SOCREATE_MIRROR_BASE}/${SOCREATE_RELEASEVER}/iso/${NETINST_ISO}}"
export SOCREATE_MIRROR_BASE SOCREATE_RELEASEVER SOCREATE_REPO_ARCH SOCREATE_KS_API SOCREATE_NETINST_URL

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

echo "==> Stage local install tree: $STAGE_DIR"
rm -rf "$STAGE_DIR"
mkdir -p "$REPO_DIR" "$KS_DIR"

echo "==> Collect Socreate RPMs"
/bin/cp -f "$(pick_latest "$TOPDIR/RPMS/noarch/socreate-release-${RELEASEVER}-*.noarch.rpm")" "$REPO_DIR/"
/bin/cp -f "$(pick_latest "$TOPDIR/RPMS/noarch/socreate-repos-${RELEASEVER}-*.noarch.rpm")" "$REPO_DIR/"
/bin/cp -f "$(pick_latest "$TOPDIR/RPMS/noarch/socreate-logos-*.noarch.rpm")" "$REPO_DIR/"
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
        /bin/cp -f "$rpm" "$REPO_DIR/"
    done
done
for pattern in \
    "$TOPDIR/RPMS/x86_64/kernel-[0-9]*.rpm" \
    "$TOPDIR/RPMS/x86_64/kernel-core-[0-9]*.rpm" \
    "$TOPDIR/RPMS/x86_64/kernel-modules-core-[0-9]*.rpm" \
    "$TOPDIR/RPMS/x86_64/kernel-modules-[0-9]*.rpm" \
    "$TOPDIR/RPMS/x86_64/kernel-devel-[0-9]*.rpm"
do
    for rpm in $pattern; do
        [[ -f "$rpm" ]] || continue
        base="$(basename "$rpm")"
        [[ "$base" == *-matched-* || "$base" == kernel-modules-extra-* || "$base" == kernel-uki-* ]] && continue
        /bin/cp -f "$rpm" "$REPO_DIR/"
    done
done

echo "==> Create local repo metadata (with desktop comps)"
createrepo_c --quiet ${COMPS_FILE:+--groupfile "$COMPS_FILE"} "$REPO_DIR"

echo "==> Render kickstart templates (mirror=${SOCREATE_MIRROR_BASE})"
bash "$TOPDIR/scripts/ci/render-kickstart.sh"

echo "==> Copy kickstart files"
/bin/cp -f "$TOPDIR/kickstart/"*.ks "$KS_DIR/"

cat > "$STAGE_DIR/serve.sh" <<'EOF'
#!/usr/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
PORT="${PORT:-8080}"
echo "Serving Socreate local install media on http://0.0.0.0:${PORT}/"
echo "Kickstart: http://<host>:${PORT}/kickstart/socreate-server.ks"
echo "Repo:      http://<host>:${PORT}/socreate/"
echo ""
echo "After install, add a desktop from the Socreate repo:"
echo "  dnf group install socreate-gnome-desktop"
echo "  dnf group install socreate-kde-desktop"
cd "$ROOT"
python3 -m http.server "$PORT"
EOF
chmod +x "$STAGE_DIR/serve.sh"

echo "==> Create tarball: $TARBALL"
mkdir -p "$DIST_DIR"
tar -C "$TOPDIR/dist" -czf "$TARBALL" "$(basename "$STAGE_DIR")"

if [[ "$BUILD_ISO" == "1" ]]; then
    if [[ "$BUILD_ANACONDA" == "1" ]] && ! ls "$TOPDIR/RPMS/x86_64/anaconda-core-"*.rpm >/dev/null 2>&1; then
        echo "==> Build Socreate Anaconda (GUI, patched source)"
        bash "$TOPDIR/scripts/ci/build-anaconda.sh"
    fi

    if [[ ! -f "$NETINST_CACHE" ]]; then
        if [[ -n "$NETINST_URL" ]]; then
            echo "==> Download Socreate netinst base: $NETINST_URL"
            curl -fL --retry 3 --retry-delay 5 -o "$NETINST_CACHE" "$NETINST_URL"
        elif [[ -f "$NETINST_FALLBACK" ]]; then
            echo "==> Seed netinst base from builder cache: $NETINST_FALLBACK"
            /bin/cp -f "$NETINST_FALLBACK" "$NETINST_CACHE"
        else
            echo "ERROR: No netinst base ISO. Set SOCREATE_NETINST_URL or place:" >&2
            echo "  $NETINST_CACHE" >&2
            echo "  $NETINST_FALLBACK" >&2
            exit 1
        fi
    else
        echo "==> Reuse cached netinst: $NETINST_CACHE"
    fi

    NETINST_PATCHED="$DIST_DIR/${NETINST_ISO%.iso}.patched.iso"
    INSTALL_IMG="$DIST_DIR/install.img.work"

    if [[ "$PATCH_INSTALL_IMG" == "1" ]] && ls "$TOPDIR/RPMS/x86_64/anaconda-core-"*.rpm >/dev/null 2>&1; then
        echo "==> Extract install.img from netinst"
        rm -f "$INSTALL_IMG"
        xorriso -osirrox on -indev "$NETINST_CACHE" -extract /images/install.img "$INSTALL_IMG"

        echo "==> Patch install.img with Socreate Anaconda GUI"
        chmod +x "$TOPDIR/scripts/ci/patch-install-img.sh"
        bash "$TOPDIR/scripts/ci/patch-install-img.sh" "$INSTALL_IMG"

        echo "==> Write patched install.img back into netinst copy"
        cp -f "$NETINST_CACHE" "$NETINST_PATCHED"
        xorriso -indev "$NETINST_PATCHED" -outdev "$NETINST_PATCHED" \
            -boot_image any replay \
            -map "$INSTALL_IMG" /images/install.img
        NETINST_INPUT="$NETINST_PATCHED"
    else
        NETINST_INPUT="$NETINST_CACHE"
    fi

    echo "==> Build bootable ISO with mkksiso"
    rm -f "$ISO_OUT"
    mkksiso \
        --ks "$KS_DIR/socreate-server.ks" \
        -a "$REPO_DIR" \
        -a "$KS_DIR" \
        -V "SOC${RELEASEVER}" \
        -c "inst.ks=hd:LABEL=SOC${RELEASEVER}:/kickstart/socreate-server.ks inst.profile=socreate inst.graphical" \
        "$NETINST_INPUT" \
        "$ISO_OUT"
fi

if mountpoint -q /mnt/hgfs/share 2>/dev/null || [[ -d /mnt/hgfs/share ]]; then
    echo "==> Copy artifacts to shared folder"
    /bin/cp -f "$TARBALL" /mnt/hgfs/share/
    [[ -f "$ISO_OUT" ]] && /bin/cp -f "$ISO_OUT" /mnt/hgfs/share/
fi

echo "==> Done"
ls -lh "$TARBALL"
[[ -f "$ISO_OUT" ]] && ls -lh "$ISO_OUT"
ls -lh "$REPO_DIR"/*.rpm | wc -l | xargs -I{} echo "RPM count: {}"
echo "Test HTTP install:"
echo "  tar -xzf $TARBALL && cd $(basename "$STAGE_DIR") && ./serve.sh"
