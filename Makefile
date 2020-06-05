PROJECT ?= linstor-csi
REGISTRY ?= drbd.io
TAG ?= latest
NOCACHE ?= false
ARCH ?= amd64

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
	for r in $(REGISTRY); do \
		docker tag $(PROJECT):$(TAG) $$r/$(PROJECT):$(TAG) ; \
		docker tag $(PROJECT):$(TAG) $$r/$(PROJECT):latest ; \
		docker push $$r/$(PROJECT):$(TAG) ; \
		docker push $$r/$(PROJECT):latest ; \
	done
