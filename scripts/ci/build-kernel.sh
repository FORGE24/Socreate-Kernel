#!/usr/bin/bash
set -euo pipefail

TOPDIR="${TOPDIR:-$(cd "$(dirname "$0")/../.." && pwd)}"
cd "$TOPDIR"

FEDORA_VERSION="${FEDORA_VERSION:-44}"
KERNEL_NEVR="${KERNEL_NEVR:-7.0.12-201.fc44}"
JOBS="${JOBS:-$(nproc)}"
KERNEL_SRPM_URL="${KERNEL_SRPM_URL:-https://dl.fedoraproject.org/pub/fedora/linux/updates/${FEDORA_VERSION}/Everything/source/tree/Packages/k/kernel-${KERNEL_NEVR}.src.rpm}"

echo "==> Install socreate-release (provides %dist .soc26h1q2)"
rpm -Uvh RPMS/noarch/socreate-release-*.noarch.rpm RPMS/noarch/socreate-repos-*.noarch.rpm
rpm --eval '%{dist}'

echo "==> Download kernel SRPM: ${KERNEL_SRPM_URL}"
curl -fL --retry 3 --retry-delay 5 -o "SOURCES/kernel-${KERNEL_NEVR}.src.rpm" "${KERNEL_SRPM_URL}"

echo "==> Install kernel SRPM into rpmbuild tree"
rpm -Uvh "SOURCES/kernel-${KERNEL_NEVR}.src.rpm"

echo "==> Install build dependencies"
dnf builddep -y SPECS/kernel.spec

echo "==> Build kernel (debug variants disabled)"
# Command-line --define overrides spec %define debugbuildsenabled
rpmbuild -bb \
    --define "debugbuildsenabled 0" \
    --define "_smp_mflags -j${JOBS}" \
    SPECS/kernel.spec

echo "==> Kernel RPMs:"
ls -lh RPMS/x86_64/kernel-*soc*.rpm 2>/dev/null || ls -lh RPMS/x86_64/kernel-*.rpm
