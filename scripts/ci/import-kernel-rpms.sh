#!/usr/bin/bash
# Import CL/K8s-compiled kernel RPMs into RPMS/x86_64.
# Extracts kernel-core, kernel-modules, kernel-devel (+ required deps) from a zip or directory.
set -euo pipefail

TOPDIR="${TOPDIR:-$(cd "$(dirname "$0")/../.." && pwd)}"
ARTIFACT_DIR="${ARTIFACT_DIR:-$TOPDIR/RPMS/x86_64}"

KERNEL_IMPORT="${KERNEL_IMPORT:-}"
KERNEL_IMPORT_ZIP="${KERNEL_IMPORT_ZIP:-}"
KERNEL_IMPORT_DIR="${KERNEL_IMPORT_DIR:-}"

# Default: shared-folder zip from CL build
if [[ -z "$KERNEL_IMPORT" && -z "$KERNEL_IMPORT_ZIP" && -z "$KERNEL_IMPORT_DIR" ]]; then
    if [[ -f /mnt/hgfs/share/kernel-rpms.zip ]]; then
        KERNEL_IMPORT_ZIP=/mnt/hgfs/share/kernel-rpms.zip
    fi
fi

if [[ -n "$KERNEL_IMPORT" ]]; then
    if [[ -f "$KERNEL_IMPORT" && "$KERNEL_IMPORT" == *.zip ]]; then
        KERNEL_IMPORT_ZIP="$KERNEL_IMPORT"
    elif [[ -d "$KERNEL_IMPORT" ]]; then
        KERNEL_IMPORT_DIR="$KERNEL_IMPORT"
    elif [[ -f "$KERNEL_IMPORT" && "$KERNEL_IMPORT" == *.rpm ]]; then
        KERNEL_IMPORT_DIR="$(dirname "$KERNEL_IMPORT")"
    else
        echo "KERNEL_IMPORT must be a zip, directory, or rpm path: $KERNEL_IMPORT"
        exit 1
    fi
fi

# RPM globs to publish (kernel-modules-core is required by kernel-modules)
IMPORT_PATTERNS=(
    'kernel-[0-9]*.rpm'
    'kernel-core-[0-9]*.rpm'
    'kernel-modules-core-[0-9]*.rpm'
    'kernel-modules-[0-9]*.rpm'
    'kernel-devel-[0-9]*.rpm'
)

tmpdir="$(mktemp -d)"
cleanup() { rm -rf "$tmpdir"; }
trap cleanup EXIT

extract_src="$tmpdir/import"

if [[ -n "$KERNEL_IMPORT_ZIP" ]]; then
    if [[ ! -f "$KERNEL_IMPORT_ZIP" ]]; then
        echo "Zip not found: $KERNEL_IMPORT_ZIP"
        exit 1
    fi
    echo "==> Extract kernel RPMs from zip: $KERNEL_IMPORT_ZIP"
    mkdir -p "$extract_src"
    unzip -o "$KERNEL_IMPORT_ZIP" -d "$extract_src"
elif [[ -n "$KERNEL_IMPORT_DIR" ]]; then
    if [[ ! -d "$KERNEL_IMPORT_DIR" ]]; then
        echo "Directory not found: $KERNEL_IMPORT_DIR"
        exit 1
    fi
    echo "==> Import kernel RPMs from directory: $KERNEL_IMPORT_DIR"
    extract_src="$KERNEL_IMPORT_DIR"
else
    echo "No kernel import source. Set KERNEL_IMPORT, KERNEL_IMPORT_ZIP, or KERNEL_IMPORT_DIR."
    exit 1
fi

mkdir -p "$ARTIFACT_DIR"
shopt -s nullglob
found=0

for pattern in "${IMPORT_PATTERNS[@]}"; do
    for rpm in "$extract_src"/$pattern; do
        base="$(basename "$rpm")"
        # Skip matched/meta helper packages
        if [[ "$base" == *-matched-* || "$base" == kernel-modules-extra-* || "$base" == kernel-modules-internal-* || "$base" == kernel-uki-* ]]; then
            continue
        fi
        install -m 0644 "$rpm" "$ARTIFACT_DIR/$base"
        echo "  + $base"
        found=1
    done
done

if [[ "$found" -eq 0 ]]; then
    echo "No kernel-core/kernel-modules/kernel-devel RPMs found under $extract_src"
    ls -la "$extract_src" || true
    exit 1
fi

echo "==> Imported kernel RPMs:"
ls -lh "$ARTIFACT_DIR"/kernel-{,core-,modules-,modules-core-,devel-}*.rpm 2>/dev/null \
    || ls -lh "$ARTIFACT_DIR"/kernel*.rpm
