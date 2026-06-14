%define debug_package %{nil}

%define releasever 26H1Q2
%define socreate_rel 1
%define rpm_license BSD-3-Clause
%define dist .soc26h1q2

Name:           socreate-comps
Version:        %{releasever}
Release:        %{socreate_rel}%{dist}
Summary:        Socreate OS DNF group and environment definitions
License:        %{rpm_license}
URL:            https://socreate.xyz/
BuildArch:      noarch

Provides:       socreate-comps = %{version}-%{release}
Provides:       comps-extras

Source0:        socreate-comps.xml

%description
Socreate OS comps definitions for DNF/YUM, including GNOME and KDE Plasma
desktop environments and Socreate branding groups.

%prep
# Source referenced directly.

%build
# no build step

%install
rm -rf %{buildroot}

install -d -m 0755 %{buildroot}%{_sysconfdir}/comps
install -m 0644 %{SOURCE0} %{buildroot}%{_sysconfdir}/comps/socreate-comps.xml

install -d -m 0755 %{buildroot}%{_prefix}/lib/socreate-release.d
cat > %{buildroot}%{_prefix}/lib/socreate-release.d/gnome << 'EOF'
VARIANT="GNOME Workstation Edition"
VARIANT_ID=workstation-gnome
EOF
cat > %{buildroot}%{_prefix}/lib/socreate-release.d/kde << 'EOF'
VARIANT="KDE Plasma Workstation Edition"
VARIANT_ID=workstation-kde
EOF

install -d -m 0755 %{buildroot}%{_libexecdir}/socreate
cat > %{buildroot}%{_libexecdir}/socreate/apply-release-flavor << 'EOF'
#!/usr/bin/bash
set -euo pipefail

flavor="$1"
overlay="/usr/lib/socreate-release.d/${flavor}"
os_release="/usr/lib/os-release"

[[ -f "$overlay" ]] || exit 0
[[ -f "$os_release" ]] || exit 0

variant_line="$(grep '^VARIANT=' "$overlay")"
variant_id_line="$(grep '^VARIANT_ID=' "$overlay")"
pretty="$(grep '^PRETTY_NAME=' "$os_release" | sed 's/^PRETTY_NAME=//' | tr -d '"')"
pretty="${pretty// Server Edition/}"
case "$flavor" in
    gnome) pretty="${pretty} GNOME Workstation Edition" ;;
    kde)   pretty="${pretty} KDE Plasma Workstation Edition" ;;
esac

tmp="$(mktemp)"
grep -Ev '^(VARIANT=|VARIANT_ID=|PRETTY_NAME=)' "$os_release" > "$tmp"
{
    cat "$tmp"
    echo "$variant_line"
    echo "$variant_id_line"
    echo "PRETTY_NAME=\"${pretty}\""
} > "${os_release}.new"
mv "${os_release}.new" "$os_release"
rm -f "$tmp"

if [[ -L /etc/os-release || -f /etc/os-release ]]; then
    ln -sf ../usr/lib/os-release /etc/os-release
fi
EOF
chmod 0755 %{buildroot}%{_libexecdir}/socreate/apply-release-flavor

%files
%config(noreplace) %{_sysconfdir}/comps/socreate-comps.xml
%{_prefix}/lib/socreate-release.d/gnome
%{_prefix}/lib/socreate-release.d/kde
%{_libexecdir}/socreate/apply-release-flavor

%changelog
* Sat Jun 13 2026 Socreate OS Project <release@socreate.xyz> - 26H1Q2-1
- Add GNOME and KDE Plasma desktop environment groups for Socreate OS repos
