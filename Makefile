PROJECT ?= linstor-csi
REGISTRY := drbd.io
ARCH ?= amd64
ifneq ($(strip $(ARCH)),)
REGISTRY := $(REGISTRY)/$(ARCH)
endif
SEMVER ?= 0.0.0+$(shell git rev-parse --short HEAD)
TAG ?= latest
NOCACHE ?= false
REPO_SOURCE ?= centos:8

help:
	@echo "Useful targets: 'update', 'upload'"

all: update upload

.PHONY: update
update: Dockerfile
	docker buildx build --load --build-arg=REPO_SOURCE=$(REPO_SOURCE) --build-arg=SEMVER=$(SEMVER) --no-cache=$(NOCACHE) -t $(PROJECT):$(TAG) .

.PHONY: upload
upload:
	docker tag $(PROJECT):$(TAG) $(REGISTRY)/$(PROJECT):$(TAG)
	docker push $(REGISTRY)/$(PROJECT):$(TAG)

prepare-release:
	sed -i "s/ARG SEMVER=.*/ARG SEMVER=$(SEMVER)/" Dockerfile

.PHONY: test/bin
test/bin:
	cd $(PROJECT) ; CGO_ENABLED=0 go test -v -a -ldflags '-extldflags "-static"' -o $(abspath $@)/sanity -c ./pkg/driver
	CGO_ENABLED=0 go build -v -a -ldflags '-extldflags "-static"' -o $(abspath $@)/e2e ./cmd/linstor-csi-e2e-test
