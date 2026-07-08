ARG REPO_SOURCE=centos:9
FROM $REPO_SOURCE AS repo-source

FROM --platform=$BUILDPLATFORM golang:1 AS gobuilder

WORKDIR /src
COPY --link /linstor-csi/go.mod /linstor-csi/go.sum /src/
ARG GOPROXY
RUN go mod download
COPY --link /linstor-csi/cmd /src/cmd
COPY --link /linstor-csi/pkg /src/pkg

ARG TARGETARCH
ARG TARGETOS
ARG SEMVER=unknown
RUN --mount=type=cache,target=/root/.cache/go-build GOOS=$TARGETOS GOARCH=$TARGETARCH CGO_ENABLED=0 \
    go build \
    -a \
    -ldflags "-X github.com/piraeusdatastore/linstor-csi/pkg/driver.Version=$SEMVER -extldflags -static"  \
    -o /nfs-helper  \
    ./cmd/nfs-helper


FROM registry.access.redhat.com/ubi9/ubi-init

# nfs-ganesha + libntirpc from the CentOS Storage SIG.
RUN --mount=type=bind,from=repo-source,source=/run/secrets,target=/run/secrets \
    dnf install -y \
      --setopt=install_weak_deps=false \
      --repofrompath="centos-sig-nfsganesha,https://mirror.stream.centos.org/SIGs/9-stream/storage/$(uname -m)/nfsganesha-9/" \
      --setopt=centos-sig-nfsganesha.gpgcheck=1 \
      --setopt=centos-sig-nfsganesha.gpgkey=https://www.centos.org/keys/RPM-GPG-KEY-CentOS-SIG-Storage \
      nfs-ganesha nfs-ganesha-vfs && \
    dnf clean all -y

RUN --mount=type=bind,from=repo-source,source=/run/secrets,target=/run/secrets \
    --mount=type=secret,id=linbit.repo,target=/etc/yum.repos.d/linbit.repo,required=true \
    dnf install -y \
      --disablerepo=* \
      --setopt=install_weak_deps=false \
      https://packages.linbit.com/public/linbit-keyring.rpm && \
    dnf install -y \
      --setopt=install_weak_deps=false \
      drbd-reactor xfsprogs e2fsprogs && \
    sed -e 's/usage-count yes;/usage-count no;/' -i /etc/drbd.d/global_common.conf && \
    dnf clean all -y

COPY --from=gobuilder --link --chmod=0755 /nfs-helper /usr/bin/nfs-helper
COPY --link --chmod=0644 /linstor-csi/nfs/service/nfs-ganesha@.service /linstor-csi/nfs/service/growfs@.service /linstor-csi/nfs/service/growfs@.timer /linstor-csi/nfs/service/mount-export@.service /linstor-csi/nfs/service/mount-recovery@.service /linstor-csi/nfs/service/chmod@.service /linstor-csi/nfs/service/prepare-device-links@.service /linstor-csi/nfs/service/advertise-nfs-endpoint@.service /linstor-csi/nfs/service/clean-nfs-endpoint@.service /linstor-csi/nfs/service/start-stop-reactor.service /usr/lib/systemd/system/
COPY --link --chmod=0644 /linstor-csi/nfs/service/drbd@.service.override.conf /usr/lib/systemd/system/drbd@.service.d/container.conf
COPY --link --chmod=0644 /linstor-csi/nfs/service/drbd-demote-or-escalate@.service.override.conf /usr/lib/systemd/system/drbd-demote-or-escalate@.service.d/container.conf
COPY --link --chmod=0644 /linstor-csi/nfs/service/default-config.tmpl /etc/nfs-helper/default-config.tmpl
COPY --link /linstor-csi/nfs/service/journald.conf /etc/systemd/journald.conf

RUN \
    # Random stuff we don't need in the container.
    systemctl disable nfs-client.target dnf-makecache.timer && \
    systemctl mask systemd-tmpfiles-setup.service systemd-tmpfiles-clean.timer && \
    # The reason this image exists. reactor is started by the reconcile-nfs service. \
    systemctl disable drbd-reactor.service && \
    systemctl enable start-stop-reactor.service

ARG SEMVER=unknown
ARG RELEASE=1
LABEL name="LINSTOR CSI NFS Server" \
      vendor="LINBIT" \
      version="$SEMVER" \
      release="$RELEASE" \
      summary="LINSTOR's CSI NFS Server component" \
      description="LINSTOR's CSI NFS Server component"
COPY LICENSE /licenses/gpl-2.0.txt

STOPSIGNAL SIGRTMIN+3
ENV container=oci SYSTEMD_GETTY_AUTO=no
