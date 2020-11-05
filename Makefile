PROJECT ?= linstor-csi
REGISTRY := drbd.io
ARCH ?= amd64
ifneq ($(strip $(ARCH)),)
REGISTRY := $(REGISTRY)/$(ARCH)
endif
SEMVER ?= 0.0.0+$(shell git rev-parse --short HEAD)
TAG ?= latest
NOCACHE ?= false

help:
	@echo "Useful targets: 'update', 'upload'"

all: update upload

.PHONY: update
update: Dockerfile
	docker build --build-arg=SEMVER=$(SEMVER) --build-arg=ARCH=$(ARCH) --no-cache=$(NOCACHE) -t $(PROJECT):$(TAG) .

.PHONY: upload
upload:
	docker tag $(PROJECT):$(TAG) $(REGISTRY)/$(PROJECT):$(TAG)
	docker push $(REGISTRY)/$(PROJECT):$(TAG)
