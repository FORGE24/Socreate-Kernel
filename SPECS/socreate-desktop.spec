%define debug_package %{nil}

%define releasever 26H1Q2
%define platform_api 44
%define socreate_rel 1
%define rpm_license BSD-3-Clause
%define dist .soc26h1q2
%define home_url https://socreate.xyz/

Name:           socreate-desktop
Version:        %{releasever}
Release:        %{socreate_rel}%{dist}
Summary:        Socreate OS desktop environment metapackages
License:        %{rpm_license}
URL:            %{home_url}
BuildArch:      noarch

Requires:       socreate-release = %{releasever}
Requires:       socreate-repos(%{releasever})
Requires:       socreate-logos
Requires:       socreate-comps = %{releasever}

%description
Metapackages for installing GNOME or KDE Plasma desktop environments on
Socreate OS from the Socreate software repositories.

%package -n socreate-desktop-gnome
Summary:        Socreate OS GNOME desktop metapackage
Requires:       socreate-desktop = %{version}-%{release}
Requires:       socreate-release-gnome = %{releasever}
Requires:       gdm
Requires:       gnome-shell
Requires:       gnome-session
Requires:       xorg-x11-server-Xwayland
Provides:       socreate-desktop-flavor = gnome
Provides:       socreate-desktop-product = gnome
Conflicts:      socreate-desktop-kde
Obsoletes:      socreate-desktop-kde < %{version}-%{release}

%description -n socreate-desktop-gnome
Install the Socreate OS GNOME desktop stack and apply GNOME Workstation
identity to the system.

%package -n socreate-release-gnome
Summary:        Socreate OS GNOME Workstation release identity
Requires:       socreate-comps = %{releasever}
Provides:       socreate-release-workstation = %{platform_api}-999
Provides:       socreate-release-identity-workstation = %{platform_api}-999
Provides:       system-release-product = workstation
Provides:       socreate-release-flavor = gnome
Provides:       fedora-release-workstation = %{platform_api}-999
Provides:       fedora-release-identity-workstation = %{platform_api}-999
Conflicts:      socreate-release-kde
Conflicts:      socreate-desktop-kde

%description -n socreate-release-gnome
GNOME Workstation identity files for Socreate OS.

%package -n socreate-desktop-kde
Summary:        Socreate OS KDE Plasma desktop metapackage
Requires:       socreate-desktop = %{version}-%{release}
Requires:       socreate-release-kde = %{releasever}
Requires:       sddm
Requires:       plasma-desktop
Requires:       plasma-workspace
Requires:       kwin
Provides:       socreate-desktop-flavor = kde
Provides:       socreate-desktop-product = kde
Conflicts:      socreate-desktop-gnome
Obsoletes:      socreate-desktop-gnome < %{version}-%{release}

%description -n socreate-desktop-kde
Install the Socreate OS KDE Plasma desktop stack and apply KDE Workstation
identity to the system.

%package -n socreate-release-kde
Summary:        Socreate OS KDE Plasma release identity
Requires:       socreate-comps = %{releasever}
Provides:       socreate-release-kde-flavor = %{platform_api}-999
Provides:       fedora-release-kde = %{platform_api}-999
Provides:       fedora-release-identity-kde = %{platform_api}-999
Provides:       system-release-product = kde
Provides:       socreate-release-flavor = kde
Conflicts:      socreate-release-gnome
Conflicts:      socreate-desktop-gnome

%description -n socreate-release-kde
KDE Plasma Workstation identity files for Socreate OS.

%prep
# no sources

%build
# no build step

%install
rm -rf %{buildroot}
install -d -m 0755 %{buildroot}%{_datadir}/doc/socreate-desktop
echo "Socreate OS desktop metapackage collection." > %{buildroot}%{_datadir}/doc/socreate-desktop/README
install -d -m 0755 %{buildroot}%{_datadir}/doc/socreate-release-gnome
echo "GNOME Workstation release identity for Socreate OS." > %{buildroot}%{_datadir}/doc/socreate-release-gnome/README
install -d -m 0755 %{buildroot}%{_datadir}/doc/socreate-release-kde
echo "KDE Plasma release identity for Socreate OS." > %{buildroot}%{_datadir}/doc/socreate-release-kde/README
install -d -m 0755 %{buildroot}%{_datadir}/doc/socreate-desktop-gnome
echo "GNOME desktop metapackage for Socreate OS." > %{buildroot}%{_datadir}/doc/socreate-desktop-gnome/README
install -d -m 0755 %{buildroot}%{_datadir}/doc/socreate-desktop-kde
echo "KDE Plasma desktop metapackage for Socreate OS." > %{buildroot}%{_datadir}/doc/socreate-desktop-kde/README

%files
%{_datadir}/doc/socreate-desktop/README

%files -n socreate-release-gnome
%{_datadir}/doc/socreate-release-gnome/README

%files -n socreate-release-kde
%{_datadir}/doc/socreate-release-kde/README

%files -n socreate-desktop-gnome
%{_datadir}/doc/socreate-desktop-gnome/README

%files -n socreate-desktop-kde
%{_datadir}/doc/socreate-desktop-kde/README

%post -n socreate-release-gnome
%{_libexecdir}/socreate/apply-release-flavor gnome

%post -n socreate-release-kde
%{_libexecdir}/socreate/apply-release-flavor kde

%post -n socreate-desktop-gnome
if command -v systemctl >/dev/null 2>&1; then
    systemctl set-default graphical.target >/dev/null 2>&1 || :
    systemctl enable gdm >/dev/null 2>&1 || :
fi

%post -n socreate-desktop-kde
if command -v systemctl >/dev/null 2>&1; then
    systemctl set-default graphical.target >/dev/null 2>&1 || :
    systemctl enable sddm >/dev/null 2>&1 || :
fi

%changelog
* Sat Jun 13 2026 Socreate OS Project <release@socreate.xyz> - 26H1Q2-1
- Add GNOME and KDE Plasma desktop metapackages for Socreate OS repos
