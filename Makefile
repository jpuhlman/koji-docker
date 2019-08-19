

TOPDIR=$(PWD)
.PHONY: containers
.PHONY: rpms

all: containers
containers: rpms
	$(TOPDIR)/build-scripts/build-containers.sh

rpms: 
	$(TOPDIR)/build-scripts/build-rpm.sh
push:
	$(TOPDIR)/build-scripts/push-containers.sh

