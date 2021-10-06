# syntax=docker/dockerfile:1
ARG REPO_SOURCE=centos:8
FROM --platform=$TARGETPLATFORM $REPO_SOURCE as repo-source

FROM --platform=$BUILDPLATFORM golang:1.17 as builder
ARG TARGETARCH
ARG SEMVER=0.15.1

WORKDIR /buildroot
COPY linstor-csi /buildroot
RUN make -f container.mk staticrelease VERSION=${SEMVER} ARCH=$TARGETARCH



FROM --platform=$TARGETPLATFORM registry.access.redhat.com/ubi8/ubi-minimal:latest
MAINTAINER Roland Kammerer <roland.kammerer@linbit.com>
ARG TARGETARCH

# Add the extra repo just for this step.
RUN --mount=type=bind,from=repo-source,source=/run/secrets,target=/run/secrets \
  microdnf update \
  && microdnf install e2fsprogs xfsprogs util-linux  \
  && microdnf clean all

ARG SEMVER=0.15.1
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
