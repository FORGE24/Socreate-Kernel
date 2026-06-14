#!/usr/bin/bash
# Audit Socreate mirror repositories for connectivity and essential packages.
set -euo pipefail

TOPDIR="${TOPDIR:-$(cd "$(dirname "$0")/../.." && pwd)}"
MIRROR_DEFAULTS="$TOPDIR/SOURCES/socreate-mirror.defaults"
# shellcheck source=/dev/null
[[ -f "$MIRROR_DEFAULTS" ]] && source "$MIRROR_DEFAULTS"

export SOCREATE_MIRROR_BASE="${SOCREATE_MIRROR_BASE:-http://rope.sanrol-cloud.top}"
export SOCREATE_RELEASEVER="${SOCREATE_RELEASEVER:-26H1Q2}"
export SOCREATE_REPO_ARCH="${SOCREATE_REPO_ARCH:-x86_64}"
export SOCREATE_KERNEL_REPO_URL="${SOCREATE_KERNEL_REPO_URL:-${SOCREATE_MIRROR_BASE}/${SOCREATE_RELEASEVER}/${SOCREATE_REPO_ARCH}/socreate%20kernel%20repo/}"

python3 <<'PY'
import gzip, os, re, sys, time, urllib.request

base = os.environ["SOCREATE_MIRROR_BASE"]
releasever = os.environ["SOCREATE_RELEASEVER"]
arch = os.environ["SOCREATE_REPO_ARCH"]
kernel_url = os.environ["SOCREATE_KERNEL_REPO_URL"]

repos = [
    ("base", f"{base}/{releasever}/{arch}/"),
    ("appstream", f"{base}/{releasever}/{arch}/appstream/"),
    ("custom", f"{base}/{releasever}/{arch}/socreate-appstream/"),
    ("kernel", kernel_url),
]

essentials = [
    "bash", "coreutils", "glibc", "systemd", "dnf", "rpm", "shadow-utils",
    "kernel-core", "grub2-tools", "NetworkManager", "openssh-server", "chrony", "sudo",
    "socreate-release", "socreate-repos", "socreate-logos", "dracut",
]

def load_names(url, timeout=30):
    repomd = urllib.request.urlopen(url + "repodata/repomd.xml", timeout=timeout).read().decode()
    has_comps = bool(re.search(r'type="group"|type="comps"', repomd))
    href = re.search(r'type="primary".*?href="([^"]+primary\.xml\.gz)"', repomd, re.S)
    if not href:
        return None, has_comps, "no primary metadata"
    data = gzip.decompress(urllib.request.urlopen(url + href.group(1), timeout=timeout).read()).decode("utf-8", errors="replace")
    return set(re.findall(r"<name>([^<]+)</name>", data)), has_comps, None

print(f"Mirror audit: {base} / {releasever} / {arch}")
print("=" * 72)
fail = 0
for label, url in repos:
    t0 = time.time()
    try:
        urllib.request.urlopen(url + "repodata/repomd.xml", timeout=20).read()
    except Exception as exc:
        print(f"[FAIL] {label}: {url}")
        print(f"       repomd: {exc} ({time.time()-t0:.2f}s)")
        fail += 1
        print()
        continue
    names, has_comps, meta_err = load_names(url)
    dt = time.time() - t0
    if meta_err:
        print(f"[FAIL] {label}: {meta_err}")
        fail += 1
        print()
        continue
    present = [p for p in essentials if p in names]
    missing = [p for p in essentials if p not in names]
    status = "OK" if not missing else "WARN"
    if label in ("base", "kernel") and missing:
        status = "FAIL"
        fail += 1
    print(f"[{status}] {label}: {len(names)} pkgs, comps={has_comps}, {dt:.2f}s")
    print(f"       URL: {url}")
    if present:
        print(f"       present: {', '.join(present)}")
    if missing:
        print(f"       missing: {', '.join(missing)}")
    print()

sys.exit(1 if fail else 0)
PY
