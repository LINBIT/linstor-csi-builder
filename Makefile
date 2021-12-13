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

OUTDIR = out

TARBALL_DIR ?= $(PROJECT)-$(SEMVER)

SRC = $(shell find $(PROJECT) -name '*.go') $(PROJECT)/go.mod $(PROJECT)/go.sum
BINS = $(addprefix $(OUTDIR)/bin/linstor-csi-,$(ARCH))

PKG_SRC = linstor-csi.spec $(shell find ./debian -type f) PKG_README.md Makefile LICENSE

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
	sed -i "s/Version: .*/Version: $(SEMVER)/" linstor-csi.spec
	DEBFULLNAME='$(shell git config user.name)' DEBEMAIL='$(shell git config user.email)' dch --newversion $(SEMVER)-1 --distribution experimental "Upstream release $(shell git -C linstor-csi describe --match 'v*')"
	rpmdev-bumpspec --new=$(SEMVER) -c "Upstream release $(shell git -C linstor-csi describe --match 'v*')" linstor-csi.spec

out/test/csi-sanity-test: $(shell find ./linstor-csi -type f -name "*.go") ./linstor-csi/go.mod ./linstor-csi/go.sum
	cd linstor-csi && CGO_ENABLED=0 go test --ldflags '-extldflags "-static"' -gcflags all=-trimpath=. --asmflags all=-trimpath=. -o ../out/test/csi-sanity-test -c ./pkg/driver

bin-release: $(OUTDIR)/$(TARBALL_DIR).tar.gz

$(BINS): $(OUTDIR)/bin/linstor-csi-%:
	cd $(PROJECT) ; CGO_ENABLED=0 GOARCH=$* go build -v -a -o ../$@ -ldflags '-X github.com/piraeusdatastore/linstor-csi/pkg/driver.Version=$(SEMVER) -extldflags -static' -gcflags all=-trimpath=. --asmflags all=-trimpath=. ./cmd/linstor-csi

$(OUTDIR)/$(TARBALL_DIR).tar.gz: $(BINS) $(PKG_SRC)
	tar -cvzf $@ --transform=s%$(OUTDIR)/bin/%% --transform=s%%$(TARBALL_DIR)/% --show-transformed $^

clean:
	rm -rf $(OUTDIR)/*
