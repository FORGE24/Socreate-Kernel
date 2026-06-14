#!/usr/bin/bash
# Create Socreate OS golden master images from the reference (installed) system.
#
# Usage:
#   create-master-image.sh capture          # export manifest from this system
#   create-master-image.sh sysprep          # generalize before block clone
#   create-master-image.sh lmc              # build QCOW2 via livemedia-creator
#   create-master-image.sh rescue-script    # write offline block-capture script
#   create-master-image.sh all              # capture + build QCOW2
set -euo pipefail

TOPDIR="${TOPDIR:-$(cd "$(dirname "$0")/../.." && pwd)}"
RELEASEVER="${SOCREATE_RELEASEVER:-26H1Q2}"
FEDORA_VERSION="${FEDORA_VERSION:-44}"
DIST_DIR="$TOPDIR/dist"
STAGE_DIR="$DIST_DIR/socreate-${RELEASEVER}-local"
REPO_DIR="$STAGE_DIR/socreate"
RESULT_DIR="${RESULT_DIR:-$DIST_DIR/master-image}"
IMAGE_NAME="${IMAGE_NAME:-socreate-${RELEASEVER}-master}"
GOLDEN_KS="$TOPDIR/kickstart/socreate-golden.ks"
SHARE_DIR="${SHARE_DIR:-/mnt/hgfs/share}"

cmd="${1:-all}"

ensure_local_repo() {
    if [[ ! -f "$REPO_DIR/repodata/repomd.xml" ]]; then
        echo "==> Local Socreate repo missing; staging from RPMS"
        BUILD_ISO=0 bash "$TOPDIR/scripts/ci/package-local-install.sh"
    fi
}

prepare_ks() {
    local out="$1"
    ensure_local_repo
    [[ -f "$GOLDEN_KS" ]] || bash "$TOPDIR/scripts/imaging/capture-master-state.sh"
    sed \
        -e "s|file:///run/install/repo/socreate/|file://${REPO_DIR}/|g" \
        -e '/^graphical$/d' \
        -e '/^text$/d' \
        -e '/^cmdline$/d' \
        -e '/^reboot$/d' \
        "$GOLDEN_KS" > "$out"

    # livemedia-creator cannot size autopart layouts; use explicit LVM parts.
    python3 - "$out" <<'PY'
from pathlib import Path
import sys
path = Path(sys.argv[1])
text = path.read_text()
old = """clearpart --all --initlabel
autopart --type=lvm --nohome"""
new = """clearpart --all --initlabel
reqpart
part / --fstype="xfs" --size=6000
part swap --size=2048"""
if old not in text:
    raise SystemExit(f"Expected autopart block missing in {path}")
path.write_text(text.replace(old, new, 1))
PY
}

run_capture() {
    bash "$TOPDIR/scripts/imaging/capture-master-state.sh"
}

run_sysprep() {
    bash "$TOPDIR/scripts/imaging/sysprep-socreate.sh"
}

run_lmc() {
    local ks_work="$TOPDIR/work/socreate-golden.lmc.ks"
    mkdir -p "$TOPDIR/work"
    rm -rf "$RESULT_DIR"
    prepare_ks "$ks_work"

    if ! command -v qemu-img >/dev/null; then
        echo "==> Installing qemu-img for livemedia-creator"
        dnf -y install qemu-img
    fi

    echo "==> Build golden master disk image with livemedia-creator"
    echo "    KS:     $ks_work"
    echo "    Output: $RESULT_DIR/${IMAGE_NAME}.qcow2"

    livemedia-creator \
        --make-disk \
        --qcow2 \
        --no-virt \
        --ks "$ks_work" \
        --image-name "$IMAGE_NAME" \
        --resultdir "$RESULT_DIR" \
        --project "Socreate OS" \
        --releasever "$FEDORA_VERSION" \
        --volid "SOC${RELEASEVER}" \
        --ram 4096 \
        --vcpus 2 \
        --image-size-align 8192 \
        --timeout 7200

    local img="$RESULT_DIR/${IMAGE_NAME}.qcow2"
    [[ -f "$img" ]] || img="$(ls -1 "$RESULT_DIR"/*.qcow2 2>/dev/null | head -1)"
    if [[ -f "$img" ]]; then
        echo "==> Master image: $img"
        md5sum "$img" | tee "$RESULT_DIR/${IMAGE_NAME}.md5"
        if [[ -d "$SHARE_DIR" ]]; then
            /bin/cp -f "$img" "$SHARE_DIR/"
            /bin/cp -f "$RESULT_DIR/${IMAGE_NAME}.md5" "$SHARE_DIR/" 2>/dev/null || true
            echo "==> Copied to $SHARE_DIR"
        fi
    else
        echo "ERROR: QCOW2 not found under $RESULT_DIR" >&2
        exit 1
    fi
}

run_rescue_script() {
    local out="$DIST_DIR/capture-master-block.sh"
    cat > "$out" <<'EOF'
#!/usr/bin/bash
# Run from Socreate rescue environment after booting the installer ISO.
# Example:
#   curl -O http://<host>/capture-master-block.sh && bash capture-master-block.sh /dev/nvme0n1
set -euo pipefail

DISK="${1:-}"
OUT="${2:-/mnt/hgfs/share/socreate-26H1Q2-master.qcow2}"

if [[ -z "$DISK" || ! -b "$DISK" ]]; then
    echo "Usage: $0 /dev/nvme0n1 [/path/to/output.qcow2]" >&2
    lsblk
    exit 1
fi

command -v qemu-img >/dev/null || { echo "Install qemu-img in rescue env" >&2; exit 1; }

echo "==> Capture block device $DISK -> $OUT"
mkdir -p "$(dirname "$OUT")"
qemu-img convert -p -O qcow2 "$DISK" "$OUT"
qemu-img info "$OUT"
md5sum "$OUT"
echo "==> Done: $OUT"
EOF
    chmod +x "$out"
    echo "==> Rescue capture script: $out"
    echo "Boot installer ISO -> rescue, mount hgfs, run:"
    echo "  bash $out /dev/nvme0n1 /mnt/hgfs/share/${IMAGE_NAME}.qcow2"
    if [[ -d "$SHARE_DIR" ]]; then
        /bin/cp -f "$out" "$SHARE_DIR/"
    fi
}

case "$cmd" in
    capture)
        run_capture
        ;;
    sysprep)
        run_sysprep
        ;;
    lmc)
        run_lmc
        ;;
    rescue-script)
        run_rescue_script
        ;;
    all)
        run_capture
        run_rescue_script
        run_lmc
        ;;
    *)
        echo "Usage: $0 {capture|sysprep|lmc|rescue-script|all}" >&2
        exit 1
        ;;
esac
