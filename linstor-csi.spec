Version: 0.14.1

%global common_description %{expand:
Driver implementing the Container Storage Interface (CSI) specification for the LINSTOR software defined storage platform.
}

# If one of the produced binaries is widely known it should be used to name the
# package instead of “goname”. Separate built binaries in different subpackages
# if needed.
Name:    linstor-csi
Release: 1%{?dist}
Summary: Driver implementing the Container Storage Interface (CSI) specification for the LINSTOR software defined storage platform.

License: GPLv2 and ASL 2.0
URL:	 https://github.com/piraeusdatastore/linstor-csi
Source0: https://pkg.linbit.com/downloads/connectors/linstor-csi-%{version}.tar.gz

%description
%{common_description}

%prep
%setup -q -n %{name}-%{version}

%build

%install
install -m 0755 -vd %{buildroot}%{_bindir}
install -m 0755 -vp linstor-csi %{buildroot}%{_bindir}/linstor-csi

%check

%files
%license LICENSE
%doc PKG_README.md
%{_bindir}/*

%changelog
* Tue Sep 14 2021 Moritz "WanzenBug" Wanzenböck <moritz.wanzenboeck@linbit.com> - 0.14.0-1
- Initial package
