# Minimal Go binary packaging template.
#
# This template documents the minimal set of spec declarations, necessary to
# package Go projects that produce binaries. The sister “go-5-binary-full”
# template documents less common declarations; read it if your needs exceed
# this file.
#
# All the “go-*-” spec templates complement one another without documentation
# overlaps. Try to read them all.
#
# Building Go binaries is less automated than the rest of our Go packaging and
# requires more manual work.
#
%global goipath github.com/piraeusdatastore/linstor-csi
%global golicenses LICENSE
%global gobuild go build %{?gocompilerflags} -tags="rpm_crashtraceback ${BUILDTAGS:-}" -ldflags "${LDFLAGS:-} %{?currentgoldflags} -B 0x$(head -c20 /dev/urandom|od -An -tx1|tr -d ' \\n') -compressdwarf=false -extldflags '%__global_ldflags %{?__golang_extldflags}'" -a -v -x

Version: 0.14.0

%global common_description %{expand:
Driver implementing the Container Storage Interface (CSI) specification for the LINSTOR software defined storage platform.
}

# If one of the produced binaries is widely known it should be used to name the
# package instead of “goname”. Separate built binaries in different subpackages
# if needed.
Name:    linstor-csi
Release: 1%{?dist}
Summary: Driver implementing the Container Storage Interface (CSI) specification for the LINSTOR software defined storage platform.

License: ASL 2.0
URL:	 https://github.com/piraeusdatastore/linstor-csi
Source0: https://pkg.linbit.com/downloads/connectors/linstor-csi-%{version}.tar.gz

BuildRequires: golang >= 1.12

%description
%{common_description}

%prep
%setup -q -n linstor-csi-%{version}

%build
GO111MODULE=on %{gobuild} -mod=vendor -o linstor-csi ./cmd/linstor-csi

%install
install -m 0755 -vd %{buildroot}%{_bindir}
install -m 0755 -vp linstor-csi %{buildroot}%{_bindir}/

%check
GO111MODULE=on go test -mod=vendor ./...

%files
%license %{golicenses}
%doc README.md
%{_bindir}/*

%changelog
* Tue Sep 14 2021 Moritz "WanzenBug" Wanzenböck <moritz.wanzenboeck@linbit.com> - 0.14.0-1
- Initial package
