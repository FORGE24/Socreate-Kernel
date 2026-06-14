#!/usr/bin/bash
# Render kickstart templates (*.ks.in) with Socreate mirror and release variables.
set -euo pipefail

TOPDIR="${TOPDIR:-$(cd "$(dirname "$0")/../.." && pwd)}"
KS_DIR="${KS_DIR:-$TOPDIR/kickstart}"
OUT_DIR="${OUT_DIR:-$KS_DIR}"

# shellcheck source=/dev/null
source "${SOCREATE_MIRROR_DEFAULTS:-$TOPDIR/SOURCES/socreate-mirror.defaults}"

SOCREATE_MIRROR_BASE="${SOCREATE_MIRROR_BASE:-http://rope.sanrol-cloud.top}"
SOCREATE_RELEASEVER="${SOCREATE_RELEASEVER:-26H1Q2}"
SOCREATE_REPO_ARCH="${SOCREATE_REPO_ARCH:-x86_64}"
SOCREATE_KS_API="${SOCREATE_KS_API:-44}"

SOCREATE_REPO_URL="${SOCREATE_MIRROR_BASE}/${SOCREATE_RELEASEVER}/${SOCREATE_REPO_ARCH}/"
SOCREATE_APPSTREAM_URL="${SOCREATE_MIRROR_BASE}/${SOCREATE_RELEASEVER}/${SOCREATE_REPO_ARCH}/appstream/"
SOCREATE_CUSTOM_URL="${SOCREATE_MIRROR_BASE}/${SOCREATE_RELEASEVER}/${SOCREATE_REPO_ARCH}/socreate-appstream/"
SOCREATE_KERNEL_REPO_URL="${SOCREATE_KERNEL_REPO_URL:-${SOCREATE_MIRROR_BASE}/${SOCREATE_RELEASEVER}/${SOCREATE_REPO_ARCH}/socreate%20kernel%20repo/}"

mkdir -p "$OUT_DIR"

render_one() {
    local src="$1"
    local dst="$2"
    sed \
        -e "s|@SOCREATE_MIRROR_BASE@|${SOCREATE_MIRROR_BASE}|g" \
        -e "s|@SOCREATE_RELEASEVER@|${SOCREATE_RELEASEVER}|g" \
        -e "s|@SOCREATE_REPO_ARCH@|${SOCREATE_REPO_ARCH}|g" \
        -e "s|@SOCREATE_KS_API@|${SOCREATE_KS_API}|g" \
        -e "s|@SOCREATE_REPO_URL@|${SOCREATE_REPO_URL}|g" \
        -e "s|@SOCREATE_APPSTREAM_URL@|${SOCREATE_APPSTREAM_URL}|g" \
        -e "s|@SOCREATE_CUSTOM_URL@|${SOCREATE_CUSTOM_URL}|g" \
        -e "s|@SOCREATE_KERNEL_REPO_URL@|${SOCREATE_KERNEL_REPO_URL}|g" \
        "$src" > "$dst"
}

for template in "$KS_DIR"/*.ks.in; do
    [[ -f "$template" ]] || continue
    base="$(basename "${template%.in}")"
    echo "==> Render kickstart: $base"
    render_one "$template" "$OUT_DIR/$base"
done

# Legacy single-file kickstarts without .in suffix are generated from templates only.
for legacy in socreate-server.ks socreate-minimal.ks socreate-golden.ks; do
    if [[ -f "$KS_DIR/${legacy}.in" ]]; then
        render_one "$KS_DIR/${legacy}.in" "$OUT_DIR/$legacy"
    fi
done
