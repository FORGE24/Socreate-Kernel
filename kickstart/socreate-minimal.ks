# Socreate OS 26H1Q2 — Minimal unattended install

#version=F44
text
reboot

url --url="http://rope.sanrol-cloud.top/26H1Q2/x86_64/"
repo --name=socreate-local --baseurl=file:///run/install/repo/socreate/
repo --name=socreate-appstream --baseurl="http://rope.sanrol-cloud.top/26H1Q2/x86_64/appstream/"

lang zh_CN.UTF-8
keyboard --vckeymap=cn --xlayouts='cn'
timezone Asia/Shanghai --utc

network --bootproto=dhcp --device=link --activate
network --hostname=socreate-minimal.localdomain

selinux --enforcing
firewall --enabled --service=ssh
rootpw --plaintext socreate

bootloader --location=mbr --append="rhgb quiet"

clearpart --all --initlabel
autopart --type=plain --nohome

%packages
@core
socreate-release
socreate-repos
socreate-logos
openssh-server
chrony
NetworkManager
sudo
dnf
curl
wget
%end

firstboot --disable
services --enabled=sshd,chronyd,NetworkManager

%post --log=/root/ks-post.log
set -euxo pipefail
SOCREATE_RPM_DIR="/run/install/repo/socreate"
if [[ -d "$SOCREATE_RPM_DIR" ]]; then
    shopt -s nullglob
    rpms=(
        "$SOCREATE_RPM_DIR"/kernel-core-*.rpm
        "$SOCREATE_RPM_DIR"/kernel-modules-core-*.rpm
        "$SOCREATE_RPM_DIR"/kernel-modules-*.rpm
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
%end
