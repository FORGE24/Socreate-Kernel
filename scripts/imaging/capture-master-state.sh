#!/usr/bin/bash
# Capture the current installed Socreate OS as golden master metadata.
set -euo pipefail

TOPDIR="${TOPDIR:-$(cd "$(dirname "$0")/../.." && pwd)}"
RELEASEVER="${SOCREATE_RELEASEVER:-26H1Q2}"
MANIFEST_DIR="${MANIFEST_DIR:-$TOPDIR/dist/master-manifest}"
GOLDEN_KS="${GOLDEN_KS:-$TOPDIR/kickstart/socreate-golden.ks}"

mkdir -p "$MANIFEST_DIR"

echo "==> Capture Socreate golden master state -> $MANIFEST_DIR"

cp -f /etc/os-release "$MANIFEST_DIR/os-release"
uname -a > "$MANIFEST_DIR/uname.txt"
date -Is > "$MANIFEST_DIR/captured-at.txt"

rpm -qa --qf '%{NAME}-%{VERSION}-%{RELEASE}.%{ARCH}\n' | sort -V > "$MANIFEST_DIR/rpm-list.txt"
dnf group list --installed > "$MANIFEST_DIR/groups-installed.txt" 2>/dev/null || true
systemctl list-unit-files --type=service --state=enabled > "$MANIFEST_DIR/services-enabled.txt" 2>/dev/null || true

if [[ -f /root/anaconda-ks.cfg ]]; then
    cp -f /root/anaconda-ks.cfg "$MANIFEST_DIR/anaconda-ks.cfg"
fi

{
    echo "# Socreate golden master manifest"
    echo "# captured: $(date -Is)"
    echo "# host: $(hostname -f 2>/dev/null || hostname)"
    echo "releasever=${RELEASEVER}"
    echo "kernel=$(uname -r)"
    echo "rpm_count=$(wc -l < "$MANIFEST_DIR/rpm-list.txt")"
} > "$MANIFEST_DIR/MANIFEST.txt"

if [[ ! -f "$GOLDEN_KS" ]]; then
    echo "==> Seed kickstart/socreate-golden.ks from socreate-server.ks"
    cp -f "$TOPDIR/kickstart/socreate-server.ks" "$GOLDEN_KS"
    sed -i '1i# Socreate OS golden master kickstart (seed from socreate-server.ks)' "$GOLDEN_KS"
fi

echo "==> Write package delta (non-base packages)"
BASE_PATTERNS='^(kernel|socreate|glibc|bash|systemd|rpm|dnf|crypto|openssl|ncurses|zlib|selinux|audit|coreutils|filesystem)'
grep -Ev "$BASE_PATTERNS" "$MANIFEST_DIR/rpm-list.txt" > "$MANIFEST_DIR/rpm-delta.txt" || true

echo "==> Done"
echo "Manifest: $MANIFEST_DIR"
echo "Golden KS:  $GOLDEN_KS"
wc -l "$MANIFEST_DIR/rpm-list.txt" | awk '{print "RPM count:", $1}'
