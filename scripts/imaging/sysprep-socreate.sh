#!/usr/bin/bash
# Generalize a Socreate OS golden master before imaging or cloning.
set -euo pipefail

DRY_RUN="${DRY_RUN:-0}"

run() {
    if [[ "$DRY_RUN" == "1" ]]; then
        echo "[dry-run] $*"
    else
        "$@"
    fi
}

echo "==> Socreate sysprep (DRY_RUN=${DRY_RUN})"

if [[ "$DRY_RUN" != "1" ]]; then
    if [[ "$(id -u)" -ne 0 ]]; then
        echo "Run as root." >&2
        exit 1
    fi
fi

echo "==> Stop non-essential services"
run systemctl stop packagekit.service packagekit-offline-update.service 2>/dev/null || true
run systemctl stop abrtd.service 2>/dev/null || true

echo "==> Clear logs and temp files"
run find /var/log -type f -name '*.log' -exec truncate -s 0 {} + 2>/dev/null || true
run find /var/log -type f -name '*.log-*' -delete 2>/dev/null || true
run rm -rf /tmp/* /var/tmp/* 2>/dev/null || true
run rm -f /root/.bash_history /home/*/.bash_history 2>/dev/null || true
run history -c 2>/dev/null || true

echo "==> Reset machine identity"
run rm -f /etc/machine-id
run systemd-machine-id-setup 2>/dev/null || run touch /etc/machine-id
run rm -f /var/lib/dbus/machine-id
run ln -sf /etc/machine-id /var/lib/dbus/machine-id 2>/dev/null || true

echo "==> Regenerate SSH host keys"
run rm -f /etc/ssh/ssh_host_* 2>/dev/null || true
run ssh-keygen -A 2>/dev/null || true

echo "==> Clear NetworkManager lease/state"
run rm -f /var/lib/NetworkManager/* 2>/dev/null || true
run rm -f /etc/udev/rules.d/70-persistent-net.rules 2>/dev/null || true

echo "==> Clear cloud-init / firstboot leftovers"
run rm -rf /var/lib/cloud/instances/* 2>/dev/null || true
run rm -rf /var/lib/cloud/data/* 2>/dev/null || true
run cloud-init clean --logs --seed 2>/dev/null || true

echo "==> DNF cache cleanup"
run dnf -y clean all 2>/dev/null || true

echo "==> Mark first boot for clones"
run mkdir -p /etc/socreate
run date -Is > /etc/socreate/golden-master-sysprep.stamp

echo "==> Sync filesystem"
run sync

echo "==> Sysprep complete"
echo "Next: shut down and capture the disk image, or run create-master-image.sh lmc"
