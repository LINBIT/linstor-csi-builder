# syntax=docker/dockerfile:1
FROM --platform=$BUILDPLATFORM golang:1.17 as builder
ARG TARGETARCH
ARG SEMVER=0.14.0-rc1

WORKDIR /buildroot
COPY linstor-csi /buildroot
RUN make -f container.mk staticrelease VERSION=${SEMVER} ARCH=$TARGETARCH

FROM --platform=$TARGETPLATFORM docker.io/centos:7 as pkgsource
ARG TARGETARCH

RUN case $TARGETARCH in \
	amd64) cp /etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7 /etc/pki/rpm-gpg/tools-key ;;\
	s390x) cp /etc/pki/rpm-gpg/RPM-GPG-KEY-ClefOS-7 /etc/pki/rpm-gpg/tools-key ;;\
	*) echo "unsupported ARCH: $ARCH"; exit 1 ;;\
	esac

FROM --platform=$TARGETPLATFORM registry.access.redhat.com/ubi7/ubi:latest
MAINTAINER Roland Kammerer <roland.kammerer@linbit.com>
ARG TARGETARCH

# Recommendation for non-minimal UBI images is to run:
RUN yum -y update-minimal --security --sec-severity=Important --sec-severity=Critical

COPY --from=pkgsource /etc/pki/rpm-gpg/tools-key /etc/pki/rpm-gpg/
COPY centos_clefos_tools.sh /opt/centos_clefos_tools.sh

# Add the extra repo just for this step.
RUN /opt/centos_clefos_tools.sh "$TARGETARCH" > /etc/yum.repos.d/tools.repo \
    && yum -y install e2fsprogs xfsprogs util-linux  \
    && yum -y clean all \
    && rm /etc/yum.repos.d/tools.repo

ARG SEMVER=0.14.0-rc1
ARG RELEASE=1
LABEL name="LINSTOR CSI driver" \
      vendor="LINBIT" \
      version="$SEMVER" \
      release="$RELEASE" \
      summary="LINSTOR's CSI driver component" \
      description="LINSTOR's CSI driver component"
COPY LICENSE /licenses/gpl-2.0.txt

COPY --from=builder /buildroot/linstor-csi-linux-${TARGETARCH} /linstor-csi
ENTRYPOINT ["/linstor-csi"]
