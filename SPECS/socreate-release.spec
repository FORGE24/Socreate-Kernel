%define debug_package %{nil}

%define distro_name Socreate OS
%define distro_code Aurora

# Version: YY + Half(H1/H2) + Quarter(Q1/Q2 within half)
#   26H1Q1 = 2026 Jan-Mar    26H1Q2 = 2026 Apr-Jun
#   26H2Q1 = 2026 Jul-Sep    26H2Q2 = 2026 Oct-Dec
%define release_year 26
%define release_half H1
%define release_quarter Q2
%define release_half_lc h1
%define release_quarter_lc q2
%define releasever %{release_year}%{release_half}%{release_quarter}

%define socreate_rel 12
%define rpm_license BSD-3-Clause
%define dist .soc%{release_year}%{release_half_lc}%{release_quarter_lc}
%define home_url https://socreate.xyz/
%define doc_url https://docs.socreate.xyz/
%define support_url https://support.socreate.xyz/
%define bug_url https://bugs.socreate.xyz/
%define dist_vendor Socreate
%define os_id socreate
%define os_bug_name Socreate-OS-%{releasever}
%define support_end 2027-06-30
%define platform_api 44

# Kernel versioning: {version}-{release}.soc{YY}{h}{q}
%define kernel_version 7.0.12
%define kernel_release 201
%define kernel_dist .soc%{release_year}%{release_half_lc}%{release_quarter_lc}
%define kernel_version_full %{kernel_version}-%{kernel_release}%{kernel_dist}

%define full_release_version %{releasever}

Name:           socreate-release
Version:        %{full_release_version}
Release:        %{socreate_rel}%{dist}
Summary:        Socreate OS release files
License:        %{rpm_license}
URL:            %{home_url}
BuildArch:      noarch

Provides:       socreate-release = %{version}-%{release}
Provides:       socreate-release(upstream) = %{full_release_version}
Provides:       redhat-release = %{platform_api}-999
Provides:       system-release = %{version}-%{release}
Provides:       system-release(releasever) = %{releasever}
Provides:       system-release(%{platform_api}) = %{platform_api}
# RPM dependency aliases (no Fedora packages installed)
Provides:       fedora-release = %{platform_api}-999
Obsoletes:      fedora-release < %{platform_api}-999
Obsoletes:      fedora-release-server < %{platform_api}-999
Obsoletes:      fedora-release-common < %{platform_api}-999
Obsoletes:      fedora-release-identity-server < %{platform_api}-999
Obsoletes:      fedora-repos < %{platform_api}-999
Obsoletes:      fedora-logos < 999
Obsoletes:      fedoraproject-logos < 999
Obsoletes:      generic-logos < 999
Conflicts:      fedora-release
Conflicts:      fedora-logos
Conflicts:      fedoraproject-logos

Requires:        socreate-repos(%{releasever})
Requires:        socreate-logos

Source0:        LICENSE
Source1:        socreate.repo
Source2:        socreate-updates.repo

%description
Socreate OS release files including system identification and branding.

%package -n socreate-repos
Summary:        Socreate OS package repositories
License:        %{rpm_license}
Provides:       system-repos = %{version}-%{release}
Provides:       socreate-repos = %{version}-%{release}
Provides:       socreate-repos(%{releasever}) = %{version}-%{release}

%description -n socreate-repos
Socreate OS DNF/YUM repository definitions.

%prep
# Source files are referenced directly; no tarball to unpack.

%build
# no build step

%install
rm -rf %{buildroot}

# os-release
install -d -m 0755 %{buildroot}%{_prefix}/lib
cat > %{buildroot}%{_prefix}/lib/os-release << EOF
NAME="Socreate OS"
VERSION="%{full_release_version} (%{distro_code})"
RELEASE_TYPE=stable
ID=socreate
ID_LIKE="rhel centos"
VERSION_ID="%{full_release_version}"
VERSION_CODENAME="%{distro_code}"
PLATFORM_ID="platform:soc%{release_year}"
PRETTY_NAME="Socreate OS %{full_release_version} (%{distro_code}) Server Edition"
ANSI_COLOR="0;38;2;26;49;44"
LOGO=socreate-logo-icon
CPE_NAME="cpe:/o:socreate:socreate:%{releasever}::baseos"
HOME_URL="%{home_url}"
DOCUMENTATION_URL="%{doc_url}"
SUPPORT_URL="%{support_url}"
BUG_REPORT_URL="%{bug_url}"
REDHAT_BUGZILLA_PRODUCT="Socreate OS"
REDHAT_BUGZILLA_PRODUCT_VERSION=%{full_release_version}
REDHAT_SUPPORT_PRODUCT="Socreate OS"
REDHAT_SUPPORT_PRODUCT_VERSION=%{full_release_version}
SUPPORT_END=%{support_end}
VARIANT="Server Edition"
VARIANT_ID=server
SOCREATE_PLATFORM_API=%{platform_api}
SOCREATE_RELEASE_YEAR=%{release_year}
SOCREATE_RELEASE_HALF=%{release_half}
SOCREATE_RELEASE_QUARTER=%{release_quarter}
SOCREATE_KERNEL_VERSION=%{kernel_version}
SOCREATE_KERNEL_RELEASE=%{kernel_release}%{kernel_dist}
SOCREATE_KERNEL_VERSION_FULL=%{kernel_version_full}
EOF

install -d -m 0755 %{buildroot}%{_sysconfdir}
ln -s ../usr/lib/os-release %{buildroot}%{_sysconfdir}/os-release

# release branding files
echo "Socreate OS release %{full_release_version} (%{distro_code})" > %{buildroot}%{_sysconfdir}/socreate-release
echo "Socreate OS release %{full_release_version} (%{distro_code})" > %{buildroot}%{_prefix}/lib/socreate-release
echo "Socreate OS release %{full_release_version} (%{distro_code})" > %{buildroot}%{_sysconfdir}/redhat-release
echo "Socreate OS release %{full_release_version} (%{distro_code})" > %{buildroot}%{_sysconfdir}/system-release
echo "cpe:/o:socreate:socreate:%{releasever}::baseos" > %{buildroot}%{_sysconfdir}/system-release-cpe
echo "cpe:/o:socreate:socreate:%{releasever}::baseos" > %{buildroot}%{_prefix}/lib/system-release-cpe
echo "%{kernel_version_full}" > %{buildroot}%{_sysconfdir}/socreate-kernel-release
echo "%{kernel_version_full}" > %{buildroot}%{_prefix}/lib/socreate-kernel-release

# issue banners
cat > %{buildroot}%{_prefix}/lib/issue << 'EOF'
\S
Kernel \r on \m (\l)

EOF
cat > %{buildroot}%{_prefix}/lib/issue.net << 'EOF'
\S
Kernel \r on \m (\l)

EOF
ln -s ../usr/lib/issue %{buildroot}%{_sysconfdir}/issue
ln -s ../usr/lib/issue.net %{buildroot}%{_sysconfdir}/issue.net

# RPM dist macros
install -d -m 0755 %{buildroot}%{_prefix}/lib/rpm/macros.d
cat > %{buildroot}%{_prefix}/lib/rpm/macros.d/macros.dist << EOF
# dist macros for Socreate OS.

%%__bootstrap         ~bootstrap
%%socreate            %{releasever}
%%socreate_year       %{release_year}
%%socreate_half       %{release_half}
%%socreate_quarter    %{release_quarter}
%%socreate_kernel_version %{kernel_version}
%%socreate_kernel_release %{kernel_release}%{kernel_dist}
%%distcore            .soc%{release_year}%{release_half_lc}%{release_quarter_lc}
%%dist                %%{!?distprefix0:%%{?distprefix}}%%{expand:%%{lua:for i=0,9999 do print("%%{?distprefix" .. i .."}") end}}%%{distcore}%%{?with_bootstrap:%%{__bootstrap}}%%{?buildrelease:+build%%{buildrelease}}
%%dist_vendor         Socreate
%%dist_name           Socreate OS
%%dist_purl_namespace socreate
%%dist_home_url       %{home_url}
%%dist_bug_report_url %{bug_url}
%%socreate_platform_api %{platform_api}
%%socreate_fc%{platform_api} 1
EOF

# repository definitions (owned by socreate-repos subpackage)
install -d -m 0755 %{buildroot}%{_sysconfdir}/yum.repos.d
for repo in socreate.repo socreate-updates.repo; do
    sed \
        -e 's/@SOCREATE_RELEASEVER@/%{releasever}/g' \
        -e 's|@SOCREATE_MIRROR_BASE@|http://rope.sanrol-cloud.top|g' \
        %{_sourcedir}/$repo > %{buildroot}%{_sysconfdir}/yum.repos.d/$repo
done

# Remove any legacy third-party repo drop-ins from the build root
rm -f %{buildroot}%{_sysconfdir}/yum.repos.d/fedora*.repo

# license (main package)
install -d -m 0755 %{buildroot}%{_datadir}/licenses/socreate-release
install -m 0644 %{_sourcedir}/LICENSE %{buildroot}%{_datadir}/licenses/socreate-release/LICENSE

%files
%config(noreplace) %{_sysconfdir}/os-release
%{_prefix}/lib/os-release
%config(noreplace) %{_sysconfdir}/socreate-release
%{_prefix}/lib/socreate-release
%config(noreplace) %{_sysconfdir}/redhat-release
%config(noreplace) %{_sysconfdir}/system-release
%config(noreplace) %{_sysconfdir}/system-release-cpe
%{_prefix}/lib/system-release-cpe
%config(noreplace) %{_sysconfdir}/socreate-kernel-release
%{_prefix}/lib/socreate-kernel-release
%config(noreplace) %{_sysconfdir}/issue
%config(noreplace) %{_sysconfdir}/issue.net
%{_prefix}/lib/issue
%{_prefix}/lib/issue.net
%{_prefix}/lib/rpm/macros.d/macros.dist
%license %{_datadir}/licenses/socreate-release/LICENSE

%files -n socreate-repos
%config(noreplace) %{_sysconfdir}/yum.repos.d/socreate.repo
%config(noreplace) %{_sysconfdir}/yum.repos.d/socreate-updates.repo

%post -n socreate-repos
# Enable only Socreate repositories; disable everything else.
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

%postun -n socreate-repos
# Do not re-enable legacy repos on uninstall.

%changelog
* Sat Jun 14 2026 Socreate OS Project <release@socreate.xyz> - 26H1Q2-12
- Add socreate-kernel repo pointing to kernel overlay on official mirror

* Sat Jun 14 2026 Socreate OS Project <release@socreate.xyz> - 26H1Q2-11
- Remove Fedora branding: os-release, repos, Obsoletes/Conflicts for fedora-* packages

* Sat Jun 14 2026 Socreate OS Project <release@socreate.xyz> - 26H1Q2-10
- Point repos to Socreate official mirror (rope.sanrol-cloud.top)

* Sat Jun 13 2026 Socreate OS Project <release@socreate.xyz> - 26H1Q2-9
- Update ANSI_COLOR to match official Socreate brand palette

* Sat Jun 13 2026 Socreate OS Project <release@socreate.xyz> - 26H1Q2-8
- Require socreate-logos and use socreate-logo-icon in os-release

* Sat Jun 13 2026 Socreate OS Project <release@socreate.xyz> - 26H1Q2-7
- Fix CI build: use %%{_sourcedir} and correct changelog weekday

* Sat Jun 13 2026 Socreate OS Project <release@socreate.xyz> - 26H1Q2-6
- Fix dnf5 config-manager disable syntax in %post

* Sat Jun 13 2026 Socreate OS Project <release@socreate.xyz> - 26H1Q2-5
- Disable legacy fedora repos; fix updates source tree URL on TUNA

* Sat Jun 13 2026 Socreate OS Project <release@socreate.xyz> - 26H1Q2-4
- Add Socreate kernel version fields and fix RPM dist macros escaping

* Sat Jun 13 2026 Socreate OS Project <release@socreate.xyz> - 26H1Q2-3
- Fix fedora-release Provides version for dbus compatibility

* Sat Jun 13 2026 Socreate OS Project <release@socreate.xyz> - 26H1Q2-2
- Point repos to Tsinghua TUNA Fedora mirror (temporary)

* Sat Jun 13 2026 Socreate OS Project <release@socreate.xyz> - 26H1Q2-1
- Adopt YYHxQy version scheme (e.g. 26H1Q2)
