%define debug_package %{nil}

%define home_url https://socreate.xyz/
%define rpm_license LicenseRef-Socreate-Logos

Name:           socreate-logos
Version:        1.3
Release:        1%{?dist}
Summary:        Socreate OS branding icons and pictures
License:        %{rpm_license}
URL:            %{home_url}
BuildArch:      noarch
BuildRequires:  python3
BuildRequires:  librsvg2-tools

Provides:       fedora-logos = 999
Provides:       system-logos = %{version}-%{release}
Obsoletes:      fedora-logos < 999
Conflicts:      fedora-logos

Source0:        socreate-logos-%{version}.tar.gz

%description
The socreate-logos package contains image files and branding assets for
Socreate OS, including desktop icons, boot splash artwork, and installer
graphics.

%prep
%setup -q -n socreate-logos

%build
python3 generate-icons.py . %{_builddir}/generated

%install
rm -rf %{buildroot}

# Vector logos
install -d -m 0755 %{buildroot}%{_datadir}/socreate-logos
install -m 0644 socreate_logo.svg %{buildroot}%{_datadir}/socreate-logos/socreate_logo.svg
install -m 0644 socreate_logo_darkbackground.svg %{buildroot}%{_datadir}/socreate-logos/socreate_logo_darkbackground.svg
install -m 0644 socreate_logo_lightbackground.svg %{buildroot}%{_datadir}/socreate-logos/socreate_logo_lightbackground.svg

# Desktop / hicolor icons
for size in 16 22 24 32 36 48 96 256; do
    install -d -m 0755 %{buildroot}%{_datadir}/icons/hicolor/${size}x${size}/apps
    install -m 0644 %{_builddir}/generated/icons/${size}x${size}/socreate-logo-icon.png \
        %{buildroot}%{_datadir}/icons/hicolor/${size}x${size}/apps/socreate-logo-icon.png
    install -d -m 0755 %{buildroot}%{_datadir}/icons/hicolor/${size}x${size}/places
    install -m 0644 %{_builddir}/generated/icons/${size}x${size}/start-here.png \
        %{buildroot}%{_datadir}/icons/hicolor/${size}x${size}/places/start-here.png
done

# Scalable start-here
install -d -m 0755 %{buildroot}%{_datadir}/icons/hicolor/scalable/apps
install -m 0644 socreate_logo.svg %{buildroot}%{_datadir}/icons/hicolor/scalable/apps/start-here.svg

# Pixmaps and favicon
install -d -m 0755 %{buildroot}%{_datadir}/pixmaps
install -m 0644 %{_builddir}/generated/pixmaps/socreate-logo.png %{buildroot}%{_datadir}/pixmaps/socreate-logo.png
install -m 0644 %{_builddir}/generated/pixmaps/socreate-logo-small.png %{buildroot}%{_datadir}/pixmaps/socreate-logo-small.png
install -d -m 0755 %{buildroot}%{_sysconfdir}
install -m 0644 %{_builddir}/generated/favicon.png %{buildroot}%{_sysconfdir}/favicon.png

# Bootloader artwork
install -d -m 0755 %{buildroot}%{_datadir}/pixmaps/bootloader
install -m 0644 %{_builddir}/generated/bootloader/bootlogo_128.png %{buildroot}%{_datadir}/pixmaps/bootloader/bootlogo_128.png
install -m 0644 %{_builddir}/generated/bootloader/bootlogo_256.png %{buildroot}%{_datadir}/pixmaps/bootloader/bootlogo_256.png

# Plymouth theme
install -d -m 0755 %{buildroot}%{_datadir}/plymouth/themes/socreate
install -m 0644 plymouth/socreate.plymouth %{buildroot}%{_datadir}/plymouth/themes/socreate/socreate.plymouth
install -m 0644 %{_builddir}/generated/plymouth/watermark.png %{buildroot}%{_datadir}/plymouth/themes/socreate/watermark.png

# Anaconda server branding
install -d -m 0755 %{buildroot}%{_datadir}/anaconda/pixmaps/server
install -m 0644 anaconda/server/socreate-server.css %{buildroot}%{_datadir}/anaconda/pixmaps/server/socreate-server.css
install -m 0644 %{_builddir}/generated/anaconda/sidebar-logo.png %{buildroot}%{_datadir}/anaconda/pixmaps/server/sidebar-logo.png
install -m 0644 %{_builddir}/generated/anaconda/sidebar-bg.png %{buildroot}%{_datadir}/anaconda/pixmaps/server/sidebar-bg.png
install -m 0644 %{_builddir}/generated/anaconda/topbar-bg.png %{buildroot}%{_datadir}/anaconda/pixmaps/server/topbar-bg.png

# Anaconda workstation branding (GNOME / KDE netinst)
install -d -m 0755 %{buildroot}%{_datadir}/anaconda/pixmaps/workstation
install -m 0644 anaconda/workstation/socreate-workstation.css %{buildroot}%{_datadir}/anaconda/pixmaps/workstation/socreate-workstation.css
install -m 0644 %{_builddir}/generated/anaconda/sidebar-logo.png %{buildroot}%{_datadir}/anaconda/pixmaps/workstation/sidebar-logo.png
install -m 0644 %{_builddir}/generated/anaconda/sidebar-bg.png %{buildroot}%{_datadir}/anaconda/pixmaps/workstation/sidebar-bg.png
install -m 0644 %{_builddir}/generated/anaconda/topbar-bg.png %{buildroot}%{_datadir}/anaconda/pixmaps/workstation/topbar-bg.png

# License
install -d -m 0755 %{buildroot}%{_datadir}/licenses/socreate-logos
install -m 0644 COPYING %{buildroot}%{_datadir}/licenses/socreate-logos/COPYING

%files
%config(noreplace) %{_sysconfdir}/favicon.png
%{_datadir}/socreate-logos/
%{_datadir}/icons/hicolor/
%{_datadir}/pixmaps/socreate-logo.png
%{_datadir}/pixmaps/socreate-logo-small.png
%{_datadir}/pixmaps/bootloader/bootlogo_128.png
%{_datadir}/pixmaps/bootloader/bootlogo_256.png
%{_datadir}/plymouth/themes/socreate/
%{_datadir}/anaconda/pixmaps/server/
%{_datadir}/anaconda/pixmaps/workstation/
%license %{_datadir}/licenses/socreate-logos/COPYING

%post
if command -v gtk-update-icon-cache >/dev/null 2>&1; then
    gtk-update-icon-cache -f -t %{_datadir}/icons/hicolor >/dev/null 2>&1 || :
fi
if command -v plymouth-set-default-theme >/dev/null 2>&1; then
    plymouth-set-default-theme socreate >/dev/null 2>&1 || :
fi

%postun
if command -v gtk-update-icon-cache >/dev/null 2>&1; then
    gtk-update-icon-cache -f -t %{_datadir}/icons/hicolor >/dev/null 2>&1 || :
fi

%changelog
* Sun Jun 14 2026 Socreate OS Project <release@socreate.xyz> - 1.3-1
- Fix Anaconda GTK4 sidebar CSS and regenerate installer background assets

* Sat Jun 13 2026 Socreate OS Project <release@socreate.xyz> - 1.2-1
- Add Anaconda workstation branding for GNOME/KDE netinst ISOs

* Sat Jun 13 2026 Socreate OS Project <release@socreate.xyz> - 1.1-1
- Import official dual-ring logo artwork from shared folder

* Sat Jun 13 2026 Socreate OS Project <release@socreate.xyz> - 1.0-1
- Initial Socreate OS branding package with icons, plymouth, and anaconda assets
