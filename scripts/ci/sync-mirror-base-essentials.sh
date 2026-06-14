#!/usr/bin/bash
# Download missing base OS RPMs from an upstream Fedora mirror and stage them
# for merge into the Socreate main repository.
set -euo pipefail

TOPDIR="${TOPDIR:-$(cd "$(dirname "$0")/../.." && pwd)}"
cd "$TOPDIR"

MIRROR_DEFAULTS="$TOPDIR/SOURCES/socreate-mirror.defaults"
# shellcheck source=/dev/null
[[ -f "$MIRROR_DEFAULTS" ]] && source "$MIRROR_DEFAULTS"

RELEASEVER="${SOCREATE_RELEASEVER:-26H1Q2}"
ARCH="${SOCREATE_REPO_ARCH:-x86_64}"
KS_API="${SOCREATE_KS_API:-44}"
STAGE="$TOPDIR/dist/mirror-upload/${RELEASEVER}/${ARCH}/base-essentials"
LIST_FILE="$TOPDIR/SOURCES/mirror-base-essentials.txt"
MAX_RETRIES="${SEED_DOWNLOAD_RETRIES:-3}"
VERIFY_ONLY="${VERIFY_ONLY:-0}"

DEFAULT_MIRRORS=(
    "https://dl.fedoraproject.org/pub/fedora/linux/releases/${KS_API}/Everything/${ARCH}/os/"
    "https://download.fedoraproject.org/pub/fedora/linux/releases/${KS_API}/Everything/${ARCH}/os/"
)
if [[ -n "${FEDORA_MIRROR:-}" ]]; then
    UPSTREAM_MIRRORS=("$FEDORA_MIRROR" "${DEFAULT_MIRRORS[@]}")
else
    UPSTREAM_MIRRORS=("${DEFAULT_MIRRORS[@]}")
fi

# Seed names that satisfy a required package name on FC44+.
declare -A SEED_ALIASES=(
    [dnf]="dnf5"
)

mkdir -p "$STAGE"

mapfile -t PACKAGES < <(grep -v '^#' "$LIST_FILE" | grep -v '^[[:space:]]*$' || true)
if (( ${#PACKAGES[@]} == 0 )); then
    echo "No packages listed in $LIST_FILE" >&2
    exit 1
fi

check_network() {
    local url="$1"
    curl -fsSIL --connect-timeout 15 --max-time 30 "${url}repodata/repomd.xml" >/dev/null
}

pick_mirror() {
    local mirror
    for mirror in "${UPSTREAM_MIRRORS[@]}"; do
        echo "==> Probing mirror: $mirror" >&2
        if check_network "$mirror"; then
            echo "$mirror"
            return 0
        fi
        echo "    unreachable, trying next..." >&2
    done
    echo "No reachable Fedora mirror. Check network or set FEDORA_MIRROR." >&2
    return 1
}

verify_rpms_integrity() {
    local bad=0 rpm
    shopt -s nullglob
    for rpm in "$STAGE"/*.rpm; do
        if ! rpm -K "$rpm" >/dev/null 2>&1; then
            echo "    corrupt RPM removed: $(basename "$rpm")" >&2
            rm -f "$rpm"
            bad=1
        fi
    done
    return "$bad"
}

seed_satisfied() {
    local seed="$1"
    local alias="${SEED_ALIASES[$seed]:-$seed}"
    local rpm name
    shopt -s nullglob
    for rpm in "$STAGE"/*.rpm; do
        name="$(rpm -qp --qf '%{NAME}\n' "$rpm" 2>/dev/null || true)"
        [[ "$name" == "$seed" || "$name" == "$alias" ]] && return 0
    done
    return 1
}

list_missing_seeds() {
    local seed
    MISSING_SEEDS=()
    for seed in "${PACKAGES[@]}"; do
        seed_satisfied "$seed" || MISSING_SEEDS+=("$seed")
    done
}

report_seeds() {
    local seed present=() missing=()
    for seed in "${PACKAGES[@]}"; do
        if seed_satisfied "$seed"; then
            present+=("$seed")
        else
            missing+=("$seed")
        fi
    done
    echo "==> Seed coverage: ${#present[@]}/${#PACKAGES[@]} present"
    (( ${#missing[@]} == 0 )) || echo "    missing: ${missing[*]}"
}

download_with_dnf() {
    local upstream="$1"
    local tmpdir reposdir arch
    tmpdir="$(mktemp -d)"
    reposdir="$tmpdir/yum.repos.d"
    mkdir -p "$reposdir"
    cat > "$reposdir/fedora-upstream.repo" <<EOF
[fedora-upstream]
name=Fedora ${KS_API} Everything
baseurl=${upstream}
enabled=1
gpgcheck=0
metadata_expire=0
EOF

    local -a dnf_args=(
        -y --disablerepo='*' --enablerepo=fedora-upstream
        --setopt=reposdir="$reposdir"
        --setopt=max_parallel_downloads=4
        --setopt=minrate=1024
        download --destdir="$STAGE" --resolve --skip-unavailable
    )

    for arch in "$ARCH" noarch; do
        dnf "${dnf_args[@]}" --arch "$arch" "${PACKAGES[@]}"
    done

    rm -rf "$tmpdir"
}

download_missing_seeds() {
    local upstream="$1"
    local tmpdir reposdir seed alias
    tmpdir="$(mktemp -d)"
    reposdir="$tmpdir/yum.repos.d"
    mkdir -p "$reposdir"
    cat > "$reposdir/fedora-upstream.repo" <<EOF
[fedora-upstream]
name=Fedora ${KS_API} Everything
baseurl=${upstream}
enabled=1
gpgcheck=0
metadata_expire=0
EOF

    for seed in "${MISSING_SEEDS[@]}"; do
        alias="${SEED_ALIASES[$seed]:-$seed}"
        echo "==> Retry seed: $seed (package: $alias)"
        dnf -y --disablerepo='*' --enablerepo=fedora-upstream \
            --setopt=reposdir="$reposdir" \
            --setopt=max_parallel_downloads=4 \
            download --destdir="$STAGE" --resolve --skip-unavailable \
            --arch "$ARCH" "$alias" || true
        dnf -y --disablerepo='*' --enablerepo=fedora-upstream \
            --setopt=reposdir="$reposdir" \
            --setopt=max_parallel_downloads=4 \
            download --destdir="$STAGE" --resolve --skip-unavailable \
            --arch noarch "$alias" || true
    done
    rm -rf "$tmpdir"
}

if [[ "$VERIFY_ONLY" == "1" ]]; then
    verify_rpms_integrity || true
    list_missing_seeds
    report_seeds
    if (( ${#MISSING_SEEDS[@]} > 0 )); then
        echo "ERROR: seed verification failed" >&2
        exit 1
    fi
    if ! verify_rpms_integrity; then
        echo "ERROR: corrupt RPMs in $STAGE" >&2
        exit 1
    fi
    echo "==> Seed verification passed"
    exit 0
fi

UPSTREAM="$(pick_mirror)"
echo "==> Using mirror: $UPSTREAM"
echo "==> Seed packages: ${#PACKAGES[@]}"
echo "==> Stage dir: $STAGE"

attempt=1
while (( attempt <= MAX_RETRIES )); do
    echo ""
    echo "==> Download attempt ${attempt}/${MAX_RETRIES}"
    verify_rpms_integrity || true
    download_with_dnf "$UPSTREAM" || true
    verify_rpms_integrity || true
    list_missing_seeds
    if (( ${#MISSING_SEEDS[@]} == 0 )); then
        break
    fi
    echo "==> Missing after attempt ${attempt}: ${MISSING_SEEDS[*]}"
    download_missing_seeds "$UPSTREAM"
    verify_rpms_integrity || true
    list_missing_seeds
    if (( ${#MISSING_SEEDS[@]} == 0 )); then
        break
    fi
    attempt=$((attempt + 1))
    if (( attempt <= MAX_RETRIES )); then
        echo "==> Waiting 10s before retry..."
        sleep 10
        UPSTREAM="$(pick_mirror)"
        echo "==> Retry mirror: $UPSTREAM"
    fi
done

report_seeds
count="$(find "$STAGE" -maxdepth 1 -name '*.rpm' | wc -l)"
echo "==> Staged RPMs: ${count} ($(du -sh "$STAGE" | awk '{print $1}'))"

if (( ${#MISSING_SEEDS[@]} > 0 )); then
    echo "ERROR: seed download incomplete: ${MISSING_SEEDS[*]}" >&2
    echo "Fix network/mirror and re-run: bash scripts/ci/sync-mirror-base-essentials.sh" >&2
    exit 1
fi

if ! verify_rpms_integrity; then
    echo "ERROR: corrupt RPMs remain in $STAGE" >&2
    exit 1
fi

echo "==> All seed packages downloaded and verified"
