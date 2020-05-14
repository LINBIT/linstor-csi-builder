FROM golang:1 as builder

ENV NAME linstor-csi
ENV BDIR /usr/local/go/
ENV PDIR "${BDIR}/${NAME}"
ENV UPSTREAM "https://github.com/piraeusdatastore/${NAME}"

ARG VERSION=latest

RUN mkdir -p "$BDIR" && cd "$BDIR" && \
    git clone "$UPSTREAM" && cd "$NAME" && \
    if [ "$VERSION" = 'latest' ]; then VERSION=HEAD; fi && \
    git checkout "$VERSION" && \
    make -f container.mk staticrelease && mv ./linstor-csi-linux-amd64 /

FROM centos:centos8 as cent8
# nothing, just get it for the repos (i.e. FS-progs)

FROM registry.access.redhat.com/ubi8/ubi
MAINTAINER Roland Kammerer <roland.kammerer@linbit.com>
RUN yum -y update-minimal --security --sec-severity=Important --sec-severity=Critical && \
	yum clean all -y

COPY --from=cent8 /etc/pki/rpm-gpg/RPM-GPG-KEY-centosofficial /etc/pki/rpm-gpg/
COPY --from=cent8 /etc/yum.repos.d/CentOS-Base.repo /etc/yum.repos.d/
RUN yum install -y --disablerepo="*" --enablerepo=BaseOS e2fsprogs xfsprogs && \
	rm -f /etc/yum.repos.d/CentOS-Base.repo && yum clean all -y

ENV CSI_VERSION 0.8.1

ARG release=1
LABEL name="LINSTOR CSI driver" \
      vendor="LINBIT" \
      version="$CSI_VERSION" \
      release="$release" \
      summary="LINSTOR's CSI driver component" \
      description="LINSTOR's CSI driver component"
COPY LICENSE /licenses/gpl-2.0.txt

COPY --from=builder /linstor-csi-linux-amd64 /linstor-csi
ENTRYPOINT ["/linstor-csi"]
