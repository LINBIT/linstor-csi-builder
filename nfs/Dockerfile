ARG REPO_SOURCE=centos:9
FROM $REPO_SOURCE AS repo-source

FROM registry.access.redhat.com/ubi9/ubi AS build

RUN --mount=type=bind,from=repo-source,source=/run/secrets,target=/run/secrets dnf install --setopt=install_weak_deps=false -y '@Development Tools' '@RPM Development Tools' createrepo

FROM build AS build-libntirpc

RUN --mount=type=bind,from=repo-source,source=/run/secrets,target=/run/secrets \
    mkdir /rpms && \
    git clone -b c9s-sig-storage-nfs-ganesha-7 https://gitlab.com/CentOS/storage/libntirpc.git && \
    cd libntirpc && \
    spectool -g libntirpc.spec && \
    rpmbuild -bs --define "_sourcedir $PWD" --define "_srcrpmdir $PWD" libntirpc.spec && \
    dnf builddep --setopt=install_weak_deps=false --enablerepo=codeready-builder-for-rhel-9-$(uname -m)-rpms -y libntirpc*.src.rpm && \
    rpmbuild -ba --define "_sourcedir $PWD" --define "_srcrpmdir $PWD" --define '_rpmdir /rpms'  libntirpc.spec

RUN createrepo /rpms

FROM build AS build-nfs-ganesha

RUN --mount=type=bind,from=repo-source,source=/run/secrets,target=/run/secrets \
    --mount=type=bind,from=build-libntirpc,source=/rpms,target=/pkgs/build-libntirpc \
    mkdir /rpms && \
    dnf install --setopt=install_weak_deps=false -y libacl-devel && \
    git clone -b c9s-sig-storage-nfs-ganesha-7 https://gitlab.com/CentOS/storage/nfs-ganesha.git && \
    cd nfs-ganesha && \
    spectool -g nfs-ganesha.spec && \
    rpmbuild -bs --define "_sourcedir $PWD" --define "_srcrpmdir $PWD" nfs-ganesha.spec --without rados_recov --without rados_urls --without ceph --without rgw --without gluster --without gpfs --without saunafs --without xfs --without nullfs --without mem --without monitoring_support && \
    dnf builddep \
      --setopt=install_weak_deps=false \
      --enablerepo=codeready-builder-for-rhel-9-$(uname -m)-rpms \
      --repofrompath=libntirpc,/pkgs/build-libntirpc \
      --setopt=libntirpc.gpgcheck=0 \
      -y nfs-ganesha*.src.rpm && \
    rpmbuild -ba --define "_sourcedir $PWD" --define "_srcrpmdir $PWD" --define '_rpmdir /rpms' nfs-ganesha.spec --without rados_recov --without rados_urls --without ceph --without rgw --without gluster --without gpfs --without saunafs --without xfs --without nullfs --without mem --without monitoring_support --define 'use_fsal_rgw OFF'

RUN createrepo /rpms

FROM --platform=$BUILDPLATFORM golang:1 AS gobuilder

WORKDIR /src
COPY --link /linstor-csi/go.mod /linstor-csi/go.sum /src/
RUN go mod download
COPY --link /linstor-csi/cmd /src/cmd
COPY --link /linstor-csi/pkg /src/pkg

ARG TARGETARCH
ARG TARGETOS
ARG VERSION=unknown
RUN --mount=type=cache,target=/root/.cache/go-build GOOS=$TARGETOS GOARCH=$TARGETARCH CGO_ENABLED=0 \
    go build \
    -a \
    -ldflags "-X github.com/piraeusdatastore/linstor-csi/pkg/driver.Version=$VERSION -extldflags -static"  \
    -o /nfs-helper  \
    ./cmd/nfs-helper


FROM registry.access.redhat.com/ubi9/ubi-init

RUN --mount=type=bind,from=repo-source,source=/run/secrets,target=/run/secrets \
    --mount=type=bind,from=build-libntirpc,source=/rpms,target=/pkgs/build-libntirpc \
    --mount=type=bind,from=build-nfs-ganesha,source=/rpms,target=/pkgs/build-nfs-ganesha \
    dnf install -y \
      --setopt=install_weak_deps=false \
      --repofrompath=libntirpc,/pkgs/build-libntirpc \
      --repofrompath=nfs-ganesha,/pkgs/build-nfs-ganesha \
      --setopt=libntirpc.gpgcheck=0 \
      --setopt=nfs-ganesha.gpgcheck=0 \
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
      --enablerepo=linbit-drbd-9-staging \
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

STOPSIGNAL SIGRTMIN+3
ENV container=oci SYSTEMD_GETTY_AUTO=no
