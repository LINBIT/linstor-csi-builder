FROM golang:1 as builder

ARG SEMVER=0.12.1
ARG ARCH=amd64

WORKDIR /buildroot
COPY linstor-csi /buildroot
RUN make -f container.mk staticrelease VERSION=${SEMVER} ARCH=${ARCH}

FROM centos:centos7 as cent7
ARG ARCH=amd64
RUN case $ARCH in \
	amd64) cp /etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7 /etc/pki/rpm-gpg/tools-key ;;\
	s390x) cp /etc/pki/rpm-gpg/RPM-GPG-KEY-ClefOS-7 /etc/pki/rpm-gpg/tools-key ;;\
	*) echo "unsupported ARCH: $ARCH"; exit 1 ;;\
	esac

FROM registry.access.redhat.com/ubi7/ubi-minimal:7.8
ARG ARCH=amd64
MAINTAINER Roland Kammerer <roland.kammerer@linbit.com>

# Recommendation for non-minimal UBI images is to run:
# yum -y update-minimal --security --sec-severity=Important --sec-severity=Critical
# We use the next best thing available:
# Currently disabled until CentOS/ClefOS catch up with UBI7
# RUN microdnf update -y && rm -rf /var/cache/yum

# repo for additional tools not in UBI (cryptsetup,...)
COPY --from=cent7 /etc/pki/rpm-gpg/tools-key /etc/pki/rpm-gpg/
COPY centos_clefos_tools.sh /tmp/
RUN /tmp/centos_clefos_tools.sh "$ARCH"
RUN microdnf install e2fsprogs xfsprogs util-linux && microdnf clean all

ARG SEMVER=0.12.1
ARG RELEASE=1
LABEL name="LINSTOR CSI driver" \
      vendor="LINBIT" \
      version="$SEMVER" \
      release="$RELEASE" \
      summary="LINSTOR's CSI driver component" \
      description="LINSTOR's CSI driver component"
COPY LICENSE /licenses/gpl-2.0.txt

COPY --from=builder /buildroot/linstor-csi-linux-${ARCH} /linstor-csi
ENTRYPOINT ["/linstor-csi"]
