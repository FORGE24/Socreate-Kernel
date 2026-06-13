#!/usr/bin/bash
set -euo pipefail

TOPDIR="${TOPDIR:-$(cd "$(dirname "$0")/../.." && pwd)}"
cd "$TOPDIR"

mkdir -p "$TOPDIR"/{BUILD,BUILDROOT,RPMS,SOURCES,SPECS,SRPMS}

FEDORA_VERSION="${FEDORA_VERSION:-44}"
KERNEL_NEVR="${KERNEL_NEVR:-7.0.12-201.fc44}"
SOCREATE_DIST="${SOCREATE_DIST:-.soc26h1q2}"
KERNEL_SRPM_URL="${KERNEL_SRPM_URL:-https://dl.fedoraproject.org/pub/fedora/linux/updates/${FEDORA_VERSION}/Everything/source/tree/Packages/k/kernel-${KERNEL_NEVR}.src.rpm}"
KERNEL_SRPM="$TOPDIR/SOURCES/kernel-${KERNEL_NEVR}.src.rpm"

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
# Fast CI path: stock base kernel only, skip debug/doc/headers/debuginfo/extras.
KERNEL_BUILD_FLAGS=(
    --define "debugbuildsenabled 0"
    --define "_smp_mflags -j${JOBS}"
    --with baseonly
    --without doc
    --without headers
    --without debuginfo
    --without configchecks
    --without kabidwchk
    --without ynl
)

echo "==> Kernel rebrand dist tag: ${SOCREATE_DIST}"
echo "==> Parallel jobs: ${JOBS}"
echo "==> Build profile: baseonly (stock kernel only, no debug/doc/headers/debuginfo)"

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

echo "==> Install build dependencies (minimal profile)"
dnf builddep -y \
    --define "_topdir $TOPDIR" \
    --define "debugbuildsenabled 0" \
    --define "with_baseonly 1" \
    --define "with_debuginfo 0" \
    --define "with_doc 0" \
    --define "with_headers 0" \
    "$TOPDIR/SPECS/kernel.spec"

echo "==> Build kernel"
"${RPMBUILD[@]}" -bb \
    "${KERNEL_BUILD_FLAGS[@]}" \
    SPECS/kernel.spec

echo "==> Kernel RPMs:"
ls -lh RPMS/x86_64/kernel-{,core,modules,modules-core}-*.rpm 2>/dev/null \
    || ls -lh RPMS/x86_64/kernel-*.rpm
