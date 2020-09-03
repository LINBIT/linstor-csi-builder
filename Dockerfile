FROM golang:1 as builder

ENV NAME linstor-csi
ENV BDIR /usr/local/go/
ENV PDIR "${BDIR}/${NAME}"
ENV UPSTREAM "https://github.com/piraeusdatastore/${NAME}"

ARG VERSION=latest
ARG ARCH=amd64

RUN mkdir -p "$BDIR" && cd "$BDIR" && \
    git clone "$UPSTREAM" && cd "$NAME" && \
    if [ "$VERSION" = 'latest' ]; then VERSION=HEAD; fi && \
    git checkout "$VERSION" && \
    make -f container.mk staticrelease ARCH=${ARCH} && mv ./linstor-csi-linux-${ARCH} /

FROM centos:centos7 as cent7
ARG ARCH=amd64
RUN case $ARCH in \
	amd64) cp /etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7 /etc/pki/rpm-gpg/tools-key ;;\
	s390x) cp /etc/pki/rpm-gpg/RPM-GPG-KEY-ClefOS-7 /etc/pki/rpm-gpg/tools-key ;;\
	*) echo "unsupported ARCH: $ARCH"; exit 1 ;;\
	esac

FROM registry.access.redhat.com/ubi7/ubi
ARG ARCH=amd64
MAINTAINER Roland Kammerer <roland.kammerer@linbit.com>
RUN yum -y update-minimal --security --sec-severity=Important --sec-severity=Critical && \
	yum clean all -y


# repo for additional tools not in UBI (cryptsetup,...)
COPY --from=cent7 /etc/pki/rpm-gpg/tools-key /etc/pki/rpm-gpg/
COPY centos_clefos_tools.sh /tmp/
RUN /tmp/centos_clefos_tools.sh "$ARCH"
RUN yum install -y e2fsprogs xfsprogs && yum clean all -y

ENV CSI_VERSION 0.9.1

ARG release=1
LABEL name="LINSTOR CSI driver" \
      vendor="LINBIT" \
      version="$CSI_VERSION" \
      release="$release" \
      summary="LINSTOR's CSI driver component" \
      description="LINSTOR's CSI driver component"
COPY LICENSE /licenses/gpl-2.0.txt

COPY --from=builder /linstor-csi-linux-${ARCH} /linstor-csi
ENTRYPOINT ["/linstor-csi"]
