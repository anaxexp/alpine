-include env_make

MAKEFLAGS += --warn-undefined-variables
.DEFAULT_GOAL := build

MAKEPATH := $(abspath $(lastword $(MAKEFILE_LIST)))
PWD := $(dir $(MAKEPATH))
WORKSPACE ?= $(shell pwd)

RELEASE_SUPPORT := $(shell dirname $(abspath $(lastword $(MAKEFILE_LIST))))/.make-release-support
# we get these from CI environment if available, otherwise from git
GIT_COMMIT ?= $(shell git rev-parse --short HEAD)
GIT_BRANCH ?= $(shell git rev-parse --abbrev-ref HEAD)

USERNAME ?=$(USER)
NAMESPACE ?= anaxexp

DOCKER_REGISTRY ?=hub.docker.io
ALPINE_VER ?= 3.21.2
ALPINE_DEV ?=
NAME=$(shell basename $(CURDIR))-$(ALPINE_VER)


REPO=$(DOCKER_REGISTRY)/$(NAMESPACE)/$(NAME)
IMAGE=$(REPO)
tag := branch-$(shell basename $(GIT_BRANCH))
#IMAGE := $(NAMESPACE)/alpine
VERSION=$(shell . $(RELEASE_SUPPORT) ; getVersion)
TAG=$(shell . $(RELEASE_SUPPORT); getTag $(tag))
# Set dir of Makefile to a variable to use later




SHELL=/bin/bash
DOCKER_BUILD_CONTEXT=.
DOCKER_FILE_PATH=Dockerfile
DOCKER_BUILD_ARGS=--build-arg ALPINE_VER=$(ALPINE_VER) \
	              --build-arg ALPINE_DEV=$(ALPINE_DEV) \

.PHONY: *

ifneq ($(STABILITY_TAG),)
    ifneq ($(TAG),latest)
        override TAG := $(TAG)-$(STABILITY_TAG)
    endif
endif

ifeq ($(TAG),)
    ifneq ($(ALPINE_DEV),)
    	TAG ?= $(ALPINE_VER)-dev
    else
        TAG ?= $(ALPINE_VER)
    endif
endif

ifneq ($(ALPINE_DEV),)
    NAME := $(NAME)-dev
endif

#.PHONY: build test push shell run start stop logs clean release
#docker build -t $(REPO):$(TAG) \
#		--build-arg ALPINE_VER=$(ALPINE_VER) \
#	--build-arg ALPINE_DEV=$(ALPINE_DEV) \
#	./
## Display this help message
help:
	@awk '/^##.*$$/,/[a-zA-Z_-]+:/' $(MAKEFILE_LIST) | awk '!(NR%2){print $$0p}{p=$$0}' | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}' | sort

build: pre-build docker-build post-build

pre-build:


post-build:


pre-push:


post-push:

run:
	docker run --rm --name $(NAME) -e DEBUG=1 $(PORTS) $(VOLUMES) $(ENV) $(IMAGE):$(VERSION) $(CMD)

start:
	docker run -d --name $(NAME) $(PORTS) $(VOLUMES) $(ENV) $(IMAGE):$(VERSION)

stop:
	docker stop $(NAME)

logs:
	docker logs $(NAME)

clean:
	-docker rm -f $(NAME)

docker-build: .release
	docker build $(DOCKER_BUILD_ARGS) -t $(IMAGE):$(VERSION) $(DOCKER_BUILD_CONTEXT) -f $(DOCKER_FILE_PATH)
	@DOCKER_MAJOR=$(shell docker -v | sed -e 's/.*version //' -e 's/,.*//' | cut -d\. -f1) ; \
	DOCKER_MINOR=$(shell docker -v | sed -e 's/.*version //' -e 's/,.*//' | cut -d\. -f2) ; \
	if [ $$DOCKER_MAJOR -eq 1 ] && [ $$DOCKER_MINOR -lt 10 ] ; then \
		echo docker tag -f $(IMAGE):$(VERSION) $(IMAGE):latest ;\
		docker tag -f $(IMAGE):$(VERSION) $(IMAGE):latest ;\
	else \
		echo docker tag $(IMAGE):$(VERSION) $(IMAGE):latest ;\
		docker tag $(IMAGE):$(VERSION) $(IMAGE):latest ; \
	fi

.release:
	@echo "release=0.0.0" > .release
	@echo "tag=$(NAME)-0.0.0" >> .release
	@echo INFO: .release created
	@cat .release

release: check-status check-release build push

push: pre-push do-push post-push

do-push:
        docker push $(IMAGE):$(VERSION)
		docker push $(IMAGE):latest

test:
	IMAGE=$(IMAGE):$(VERSION) ./test.sh

shell:
	docker run --rm --name $(NAME) -i -t $(PORTS) $(VOLUMES) $(ENV) $(IMAGE):$(VERSION) /bin/bash

snapshot: build push

showver: .release
	@. $(RELEASE_SUPPORT); getVersion
	@. $(RELEASE_SUPPORT); getTag $(VERSION)

tag-patch-release: VERSION := $(shell . $(RELEASE_SUPPORT); nextPatchLevel)
tag-patch-release: .release tag 

tag-minor-release: VERSION := $(shell . $(RELEASE_SUPPORT); nextMinorLevel)
tag-minor-release: .release tag 

tag-major-release: VERSION := $(shell . $(RELEASE_SUPPORT); nextMajorLevel)
tag-major-release: .release tag 

patch-release: tag-patch-release release
	@echo $(VERSION)

minor-release: tag-minor-release release
	@echo $(VERSION)

major-release: tag-major-release release
	@echo $(VERSION)

# Docker publish
publish: publish-latest publish-version ## Publish the `{version}` ans `latest` tagged containers to ECR

publish-latest: tag-latest ## Publish the `latest` taged container to ECR
	@echo 'publish latest to $(DOCKER_REPO)'
	docker push $(DOCKER_REPO)/$(APP_NAME):latest

publish-version: tag-version ## Publish the `{version}` taged container to ECR
	@echo 'publish $(VERSION) to $(DOCKER_REPO)'
	docker push $(DOCKER_REPO)/$(APP_NAME):$(VERSION)

tag: TAG=$(shell . $(RELEASE_SUPPORT); getTag $(VERSION))
tag: check-status
	@. $(RELEASE_SUPPORT) ; ! tagExists $(TAG) || (echo "ERROR: tag $(TAG) for version $(VERSION) already tagged in git" >&2 && exit 1) ;
	@. $(RELEASE_SUPPORT) ; setRelease $(VERSION)
	git add .
	git commit -m "bumped to version $(VERSION)" ;
	git tag $(TAG) ;
	@ if [ -n "$(shell git remote -v)" ] ; then git push --tags ; else echo 'no remote to push tags to' ; fi

check-status:
	@. $(RELEASE_SUPPORT) ; ! hasChanges || (echo "ERROR: there are still outstanding changes" >&2 && exit 1) ;

check-release: .release
	@. $(RELEASE_SUPPORT) ; tagExists $(TAG) || (echo "ERROR: version not yet tagged in git. make [minor,major,patch]-release." >&2 && exit 1) ;
	@. $(RELEASE_SUPPORT) ; ! differsFromRelease $(TAG) || (echo "ERROR: current directory differs from tagged $(TAG). make [minor,major,patch]-release." ; exit 1)

## Print environment for build debugging
debug:
	@echo PWD=$(PWD)
	@echo WORKSPACE=$(WORKSPACE)
	@echo MAKEPATH=$(MAKEPATH)
	@echo RELEASE_SUPPORT=$(RELEASE_SUPPORT)
	@echo DOCKER_REGISTRY=$(DOCKER_REGISTRY)
	@echo NAMESPACE=$(NAMESPACE)
	@echo NAME=$(NAME)
	@echo IMAGE=$(IMAGE)
	@echo REPO=$(REPO)
	@echo GIT_COMMIT=$(GIT_COMMIT)
	@echo GIT_BRANCH=$(GIT_BRANCH)
	@echo VERSION=$(VERSION)
	@echo TAG=$(TAG)


version: ## Output the current version
	@echo $(VERSION)

check_var = $(foreach 1,$1,$(__check_var))
__check_var = $(if $(value $1),,\
	$(error Missing $1 $(if $(value 2),$(strip $2))))