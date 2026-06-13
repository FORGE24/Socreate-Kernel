#!/usr/bin/bash
set -euo pipefail

TOPDIR="${TOPDIR:-$(cd "$(dirname "$0")/../.." && pwd)}"
cd "$TOPDIR"

mkdir -p "$TOPDIR"/{BUILD,BUILDROOT,RPMS,SOURCES,SPECS,SRPMS}

FEDORA_VERSION="${FEDORA_VERSION:-44}"
KERNEL_NEVR="${KERNEL_NEVR:-7.0.12-201.fc44}"
JOBS="${JOBS:-$(nproc)}"
SOCREATE_DIST="${SOCREATE_DIST:-.soc26h1q2}"
KERNEL_BASEONLY="${KERNEL_BASEONLY:-1}"
KERNEL_SRPM_URL="${KERNEL_SRPM_URL:-https://dl.fedoraproject.org/pub/fedora/linux/updates/${FEDORA_VERSION}/Everything/source/tree/Packages/k/kernel-${KERNEL_NEVR}.src.rpm}"
RPMBUILD=(rpmbuild --define "_topdir $TOPDIR" --define "dist ${SOCREATE_DIST}")

echo "==> Kernel rebrand dist tag: ${SOCREATE_DIST}"
echo "==> Parallel make jobs: ${JOBS}"
echo "==> Base-only build (skip debug variants): ${KERNEL_BASEONLY}"

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

echo "==> Download kernel SRPM: ${KERNEL_SRPM_URL}"
curl -fL --retry 3 --retry-delay 5 -o "$TOPDIR/SOURCES/kernel-${KERNEL_NEVR}.src.rpm" "${KERNEL_SRPM_URL}"

echo "==> Install kernel SRPM into rpmbuild tree"
rpm -Uvh --define "_topdir $TOPDIR" "$TOPDIR/SOURCES/kernel-${KERNEL_NEVR}.src.rpm"

if [[ ! -f "$TOPDIR/SPECS/kernel.spec" ]]; then
    echo "kernel.spec not found under $TOPDIR/SPECS after SRPM install"
    ls -la "$TOPDIR/SPECS/" || true
    exit 1
fi

echo "==> Install build dependencies"
dnf builddep -y "$TOPDIR/SPECS/kernel.spec"

echo "==> Build kernel (debug variants disabled)"
RPMBUILD_ARGS=(
    --define "debugbuildsenabled 0"
    --define "_smp_mflags -j${JOBS}"
)
if [[ "${KERNEL_BASEONLY}" == "1" ]]; then
    RPMBUILD_ARGS+=(--with baseonly)
fi

"${RPMBUILD[@]}" -bb \
    "${RPMBUILD_ARGS[@]}" \
    SPECS/kernel.spec

echo "==> Kernel RPMs:"
ls -lh RPMS/x86_64/kernel-*soc*.rpm 2>/dev/null || ls -lh RPMS/x86_64/kernel-*.rpm
