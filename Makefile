PROJECT ?= linstor-csi
REGISTRY := drbd.io
ARCH ?= amd64
ifneq ($(strip $(ARCH)),)
REGISTRY := $(REGISTRY)/$(ARCH)
endif
TAG ?= latest
NOCACHE ?= false

help:
	@echo "Useful targets: 'update', 'upload'"

all: update upload

.PHONY: update
update: Dockerfile
	docker build --build-arg=VERSION=$(TAG) --build-arg=ARCH=$(ARCH) --no-cache=$(NOCACHE) -t $(PROJECT):$(TAG) .
	docker tag $(PROJECT):$(TAG) $(PROJECT):latest
	echo "" && echo "IMPORTANT:" && echo "CSI VERSION in Dockerfile: " && grep '^ENV CSI_VERSION' Dockerfile && echo "is this correct?" && echo

.PHONY: upload
upload:
	docker tag $(PROJECT):$(TAG) $(REGISTRY)/$(PROJECT):$(TAG)
	docker tag $(PROJECT):$(TAG) $(REGISTRY)/$(PROJECT):latest
	docker push $(REGISTRY)/$(PROJECT):$(TAG)
	docker push $(REGISTRY)/$(PROJECT):latest
