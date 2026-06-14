#!/usr/bin/bash
set -euo pipefail

TOPDIR="${TOPDIR:-$(cd "$(dirname "$0")/../.." && pwd)}"
cd "$TOPDIR"

mkdir -p "$TOPDIR"/{BUILD,BUILDROOT,RPMS,SOURCES,SPECS,SRPMS}

SOCREATE_KS_API="${SOCREATE_KS_API:-44}"
MIRROR_DEFAULTS="$TOPDIR/SOURCES/socreate-mirror.defaults"

# shellcheck source=/dev/null
[[ -f "$MIRROR_DEFAULTS" ]] && source "$MIRROR_DEFAULTS"
SOCREATE_MIRROR_BASE="${SOCREATE_MIRROR_BASE:-http://rope.sanrol-cloud.top}"
SOCREATE_RELEASEVER="${SOCREATE_RELEASEVER:-26H1Q2}"
KERNEL_NEVR="${KERNEL_NEVR:-7.0.12-201.fc44}"
SOCREATE_DIST="${SOCREATE_DIST:-.soc26h1q2}"
KERNEL_SRPM_URL="${KERNEL_SRPM_URL:-${SOCREATE_MIRROR_BASE}/${SOCREATE_RELEASEVER}/source/kernel-${KERNEL_NEVR}.src.rpm}"
KERNEL_SRPM="$TOPDIR/SOURCES/kernel-${KERNEL_NEVR}.src.rpm"
KERNEL_BASEONLY="${KERNEL_BASEONLY:-0}"
KERNEL_IMPORT="${KERNEL_IMPORT:-}"
KERNEL_IMPORT_ZIP="${KERNEL_IMPORT_ZIP:-}"
KERNEL_IMPORT_DIR="${KERNEL_IMPORT_DIR:-}"

# Import pre-built CL/K8s artifacts instead of compiling locally.
if [[ -n "$KERNEL_IMPORT" || -n "$KERNEL_IMPORT_ZIP" || -n "$KERNEL_IMPORT_DIR" ]]; then
    echo "==> Import CL-compiled kernel RPMs (skip local build)"
    chmod +x scripts/ci/import-kernel-rpms.sh
    KERNEL_IMPORT="$KERNEL_IMPORT" \
    KERNEL_IMPORT_ZIP="$KERNEL_IMPORT_ZIP" \
    KERNEL_IMPORT_DIR="$KERNEL_IMPORT_DIR" \
    ARTIFACT_DIR="$TOPDIR/RPMS/x86_64" \
        ./scripts/ci/import-kernel-rpms.sh
    exit 0
fi

# Use all CPUs, but cap by available RAM (~2 GiB per compile job).
if [[ -z "${JOBS:-}" ]]; then
    JOBS="$(nproc)"
    if [[ -r /proc/meminfo ]]; then
        mem_jobs=$(($(grep -E '^MemAvailable:' /proc/meminfo | awk '{print $2}') / 2097152))
        if (( mem_jobs >= 1 && JOBS > mem_jobs )); then
            JOBS=$mem_jobs
        fi
    fi
fi

RPMBUILD=(rpmbuild --define "_topdir $TOPDIR" --define "dist ${SOCREATE_DIST}")
KERNEL_BUILD_FLAGS=(
    --define "debugbuildsenabled 0"
    --define "_smp_mflags -j${JOBS}"
    --without doc
    --without debuginfo
    --without configchecks
    --without kabidwchk
    --without ynl
)

if [[ "$KERNEL_BASEONLY" == "1" ]]; then
    KERNEL_BUILD_FLAGS+=(--with baseonly --without headers)
    BUILD_PROFILE="baseonly (stock kernel, no headers/debuginfo)"
else
    BUILD_PROFILE="split (kernel-core + kernel-modules + kernel-devel)"
fi

echo "==> Kernel rebrand dist tag: ${SOCREATE_DIST}"
echo "==> Parallel jobs: ${JOBS}"
echo "==> Build profile: ${BUILD_PROFILE}"

if [[ "${INSTALL_SOCREATE_RELEASE:-0}" == "1" ]]; then
    echo "==> Installing socreate-release RPMs (local mode)"
    mkdir -p RPMS/noarch
    shopt -s nullglob
    release_rpms=(RPMS/noarch/socreate-release-*.noarch.rpm)
    repos_rpms=(RPMS/noarch/socreate-repos-*.noarch.rpm)
    if (( ${#release_rpms[@]} == 0 || ${#repos_rpms[@]} == 0 )); then
        echo "socreate-release RPMs not found under RPMS/noarch/"
        exit 1
    fi
    rpm -Uvh --replacefiles --replacepkgs "${release_rpms[@]}" "${repos_rpms[@]}"
    SOCREATE_DIST="$(rpm --eval '%{dist}')"
    RPMBUILD=(rpmbuild --define "_topdir $TOPDIR" --define "dist ${SOCREATE_DIST}")
fi

if [[ ! -f "$KERNEL_SRPM" ]]; then
    echo "==> Download kernel SRPM: ${KERNEL_SRPM_URL}"
    curl -fL --retry 3 --retry-delay 5 -o "$KERNEL_SRPM" "${KERNEL_SRPM_URL}"
else
    echo "==> Reuse cached kernel SRPM: ${KERNEL_SRPM}"
fi

echo "==> Install kernel SRPM into rpmbuild tree"
rpm -Uvh --define "_topdir $TOPDIR" "$KERNEL_SRPM"

if [[ ! -f "$TOPDIR/SPECS/kernel.spec" ]]; then
    echo "kernel.spec not found under $TOPDIR/SPECS after SRPM install"
    ls -la "$TOPDIR/SPECS/" || true
    exit 1
fi

echo "==> Install build dependencies"
dnf builddep -y \
    --define "_topdir $TOPDIR" \
    --define "debugbuildsenabled 0" \
    --define "with_baseonly ${KERNEL_BASEONLY}" \
    --define "with_debuginfo 0" \
    --define "with_doc 0" \
    --define "with_headers $([[ "$KERNEL_BASEONLY" == 1 ]] && echo 0 || echo 1)" \
    "$TOPDIR/SPECS/kernel.spec"

echo "==> Build kernel"
"${RPMBUILD[@]}" -bb \
    "${KERNEL_BUILD_FLAGS[@]}" \
    SPECS/kernel.spec

echo "==> Kernel RPMs:"
ls -lh RPMS/x86_64/kernel-{,core-,modules-,modules-core-,devel-}*.rpm 2>/dev/null \
    || ls -lh RPMS/x86_64/kernel-*.rpm
