# Socreate OS 26H1Q2 — Interactive Server Install
# GUI configures root password, disk layout, users, and network.
#
# Install source: http://rope.sanrol-cloud.top/26H1Q2/x86_64/

#version=F44
graphical
reboot

url --url="http://rope.sanrol-cloud.top/26H1Q2/x86_64/"
repo --name=socreate-appstream --baseurl="http://rope.sanrol-cloud.top/26H1Q2/x86_64/appstream/"
repo --name=socreate-custom --baseurl="http://rope.sanrol-cloud.top/26H1Q2/x86_64/socreate-appstream/"
repo --name=socreate-kernel --baseurl="http://rope.sanrol-cloud.top/26H1Q2/x86_64/socreate%20kernel%20repo/"
repo --name=socreate --baseurl=hd:LABEL=SOC26H1Q2:/socreate/

eula --agreed

lang zh_CN.UTF-8
keyboard --vckeymap=cn --xlayouts='cn'
timezone Asia/Shanghai --utc

network --bootproto=dhcp --device=link --activate

selinux --enforcing
firewall --enabled --service=ssh

bootloader --location=mbr --append="rhgb quiet crashkernel=1G-4G:192M,4G-64G:256M,64G-:512M"

# Only Socreate overlay packages; base OS packages selected in GUI.
# Mirror has no comps — do not use @environment or @group entries.
%packages
socreate-release
socreate-repos
socreate-logos
%end

firstboot --disable
services --enabled=sshd,chronyd,NetworkManager
services --disabled=bluetooth

%post --log=/root/ks-post.log
set -euxo pipefail

LOG="/root/ks-post-socreate.log"
exec > >(tee -a "$LOG") 2>&1

echo "==> Socreate OS post-install ($(date -Is))"

SOCREATE_RPM_DIR="/run/install/repo/socreate"
[[ -d /run/install/source-dir/socreate ]] && SOCREATE_RPM_DIR="/run/install/source-dir/socreate"
if [[ -d "$SOCREATE_RPM_DIR" ]]; then
    shopt -s nullglob
    rpms=(
        "$SOCREATE_RPM_DIR"/kernel-core-*.rpm
        "$SOCREATE_RPM_DIR"/kernel-modules-core-*.rpm
        "$SOCREATE_RPM_DIR"/kernel-modules-*.rpm
        "$SOCREATE_RPM_DIR"/kernel-devel-*.rpm
        "$SOCREATE_RPM_DIR"/kernel-[0-9]*.rpm
    )
    if (( ${#rpms[@]} > 0 )); then
        echo "==> Installing Socreate kernel from install media"
        dnf -y install "${rpms[@]}"
    fi
fi

shopt -s nullglob
for repofile in /etc/yum.repos.d/*.repo; do
    case "$(basename "$repofile")" in
        socreate.repo|socreate-updates.repo) continue ;;
    esac
    rm -f "$repofile"
done
for repo in $(grep -h '^\[' /etc/yum.repos.d/socreate*.repo 2>/dev/null | tr -d '[]'); do
    dnf config-manager --set-enabled "$repo" >/dev/null 2>&1 || true
done
for repo in $(grep -h '^\[' /etc/yum.repos.d/socreate-updates*.repo 2>/dev/null | tr -d '[]'); do
    dnf config-manager --set-enabled "$repo" >/dev/null 2>&1 || true
done

KVER="$(rpm -q kernel-core --qf '%{VERSION}-%{RELEASE}.%{ARCH}\n' | sort -V | tail -1)"
if [[ -n "$KVER" && -x /usr/bin/dracut ]]; then
    dracut -f --kver "$KVER" || true
fi

echo "==> Socreate post-install complete"
%end

%addon com_redhat_kdump --enable --reserve-mb=auto
%end
