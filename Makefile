PROJECT ?= linstor-csi
REGISTRY := drbd.io
ARCH ?= amd64
ifneq ($(strip $(ARCH)),)
REGISTRY := $(REGISTRY)/$(ARCH)
endif
SEMVER ?= 0.0.0+$(shell git rev-parse --short HEAD)
TAG ?= latest
BASE ?= 0.0.0
BUILD ?= alpha
BUILD_NR ?= 1
PKG_NR ?= 1
NOCACHE ?= false
REPO_SOURCE ?= centos:8

OUTDIR = ./out

TARBALL_DIR ?= $(shell eval $$(lbvers.py print --project $(PROJECT) --base $(BASE) --build $(BUILD) --build-nr $(BUILD_NR) --pkg-nr $(PKG_NR)) && echo $$TARBALL_DIR)
TARBALL_NAME ?= $(shell eval $$(lbvers.py print --project $(PROJECT) --base $(BASE) --build $(BUILD) --build-nr $(BUILD_NR) --pkg-nr $(PKG_NR)) && echo $$TARBALL_NAME)
DEB_TARBALL_NAME ?= $(patsubst $(PROJECT)-%.tar.gz,$(PROJECT)_%.orig.tar.gz,$(TARBALL_NAME))

SRC = $(PROJECT)/LICENSE $(PROJECT)/README.md $(PROJECT)/go.mod $(PROJECT)/go.sum $(shell find $(PROJECT) -name '*.go'  -type f)
VENDOR_SRC = $(addprefix build/,$(SRC))

DEB_SRC = $(shell find debian -type f)
DEB_SRC_DST = $(addprefix $(OUTDIR)/$(TARBALL_DIR)/,$(DEB_SRC))

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

	mkdir -p $@

$(OUTDIR)/$(DEB_TARBALL_NAME): $(OUTDIR)/$(TARBALL_NAME)
	mkdir -p "$$(dirname "$@")"
	ln -snf ./$(TARBALL_NAME) $@

tar: check_version $(OUTDIR)/$(TARBALL_NAME)

debsrc: check_version $(OUTDIR)/$(DEB_TARBALL_NAME) $(DEB_SRC_DST) $(OUTDIR)/$(DEB_TARBALL_NAME)
	tar -xf $(OUTDIR)/$(DEB_TARBALL_NAME) -C $(OUTDIR)

$(DEB_SRC_DST): $(OUTDIR)/$(TARBALL_DIR)/%: %
	mkdir -p "$$(dirname "$@")"
	cp -av "$^" "$@"

$(OUTDIR)/$(TARBALL_NAME): $(VENDOR_SRC)
	mkdir -p "$$(dirname "$@")"
	cd build/$(PROJECT) ; go mod vendor
	tar -cvzf $@ --transform=s%build/$(PROJECT)%$(TARBALL_DIR)% build/$(PROJECT)/

$(VENDOR_SRC): build/$(PROJECT)/%: $(PROJECT)/%
	mkdir -p "$$(dirname "$@")"
	cp -av "$^" "$@"

check_version:
	[ -n "$(SKIP_VERSION_CHECK)" ] || lbvers.py check --base $(BASE) --build $(BUILD) --build-nr $(BUILD_NR) --pkg-nr $(PKG_NR)
