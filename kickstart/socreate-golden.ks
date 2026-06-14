# Socreate OS 26H1Q2 — Golden master (LMC / reproducible image)

#version=F44

url --url="http://rope.sanrol-cloud.top/26H1Q2/x86_64/"
repo --name=socreate-local --baseurl=file:///run/install/repo/socreate/
repo --name=socreate-appstream --baseurl="http://rope.sanrol-cloud.top/26H1Q2/x86_64/appstream/"

eula --agreed

lang zh_CN.UTF-8
keyboard --vckeymap=cn --xlayouts='cn'
timezone Asia/Shanghai --utc

network --bootproto=dhcp --device=link --activate
network --hostname=socreate-master.localdomain

selinux --enforcing
firewall --enabled --service=ssh
rootpw --plaintext socreate

bootloader --location=mbr --append="rhgb quiet crashkernel=1G-4G:192M,4G-64G:256M,64G-:512M"

clearpart --all --initlabel
autopart --type=lvm --nohome

%packages
@^server-product-environment
@standard
@container-management
@guest-agents
@hardware-support
@headless-management

socreate-release
socreate-repos
socreate-logos

openssh-server
sudo
dnf-plugins-core
chrony
NetworkManager
bash-completion
vim-minimal
tar
curl
wget
git

-kernel-debug
-kernel-debug-core
-kernel-debug-devel
-kernel-debug-modules
-kernel-debug-modules-core
-kernel-debug-modules-extra
-kernel-debug-devel-matched
-kernel-debug-modules-extra-matched
-kernel-debug-modules-internal
-kernel-uki-virt
-kernel-uki-virt-addons
%end

firstboot --disable
services --enabled=sshd,chronyd,NetworkManager
services --disabled=bluetooth

%post --log=/root/ks-post.log
set -euxo pipefail
SOCREATE_RPM_DIR="/run/install/repo/socreate"
if [[ -d "$SOCREATE_RPM_DIR" ]]; then
    shopt -s nullglob
    rpms=(
        "$SOCREATE_RPM_DIR"/kernel-core-*.rpm
        "$SOCREATE_RPM_DIR"/kernel-modules-core-*.rpm
        "$SOCREATE_RPM_DIR"/kernel-modules-*.rpm
        "$SOCREATE_RPM_DIR"/kernel-devel-*.rpm
        "$SOCREATE_RPM_DIR"/kernel-[0-9]*.rpm
    )
    (( ${#rpms[@]} )) && dnf -y install "${rpms[@]}"
fi
shopt -s nullglob
for repofile in /etc/yum.repos.d/*.repo; do
    case "$(basename "$repofile")" in
        socreate.repo|socreate-updates.repo) continue ;;
    esac
    rm -f "$repofile"
done
for repo in $(grep -h '^\[' /etc/yum.repos.d/socreate*.repo /etc/yum.repos.d/socreate-updates*.repo 2>/dev/null | tr -d '[]'); do
    dnf config-manager --set-enabled "$repo" >/dev/null 2>&1 || true
done
KVER="$(rpm -q kernel-core --qf '%{VERSION}-%{RELEASE}.%{ARCH}\n' | sort -V | tail -1)"
[[ -n "$KVER" && -x /usr/bin/dracut ]] && dracut -f --kver "$KVER" || true
mkdir -p /etc/socreate
echo "golden-master" > /etc/socreate/image-type
%end

%addon com_redhat_kdump --enable --reserve-mb=auto
%end
