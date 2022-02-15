# syntax=docker/dockerfile:1
ARG REPO_SOURCE=centos:8
FROM --platform=$TARGETPLATFORM $REPO_SOURCE as repo-source

FROM --platform=$BUILDPLATFORM golang:1.17 as builder

WORKDIR /buildroot
COPY linstor-csi/go.mod linstor-csi/go.sum /buildroot/

ARG GOPROXY
RUN go mod download

COPY linstor-csi/ /buildroot/

ARG TARGETARCH
ARG SEMVER=0.17.0
RUN GOARCH=$TARGETARCH CGO_ENABLED=0 go build -a -ldflags "-X github.com/piraeusdatastore/linstor-csi/pkg/driver.Version=$SEMVER -extldflags '-static'" -o linstor-csi ./cmd/linstor-csi

FROM --platform=$BUILDPLATFORM golang:1.17 as downloader

ARG TARGETOS
ARG TARGETARCH
ARG LINSTOR_WAIT_UNTIL_VERSION=v0.1.1
RUN curl -fsSL https://github.com/LINBIT/linstor-wait-until/releases/download/$LINSTOR_WAIT_UNTIL_VERSION/linstor-wait-until-$LINSTOR_WAIT_UNTIL_VERSION-$TARGETOS-$TARGETARCH.tar.gz | tar xvzC /

FROM --platform=$TARGETPLATFORM registry.access.redhat.com/ubi8/ubi-minimal:latest
MAINTAINER Roland Kammerer <roland.kammerer@linbit.com>

# Add the extra repo just for this step.
RUN --mount=type=bind,from=repo-source,source=/run/secrets,target=/run/secrets \
  microdnf update \
  && microdnf install e2fsprogs xfsprogs util-linux  \
  && microdnf clean all

ARG SEMVER=0.17.0
ARG RELEASE=1
LABEL name="LINSTOR CSI driver" \
      vendor="LINBIT" \
      version="$SEMVER" \
      release="$RELEASE" \
      summary="LINSTOR's CSI driver component" \
      description="LINSTOR's CSI driver component"
COPY LICENSE /licenses/gpl-2.0.txt

COPY --from=builder /buildroot/linstor-csi /linstor-csi
COPY --from=downloader /linstor-wait-until /linstor-wait-until
ENTRYPOINT ["/linstor-csi"]
