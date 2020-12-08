SHELL := /bin/bash

IMAGE_NAME 				:= p4-codeception
BUILD_NAMESPACE 	?= gcr.io
GOOGLE_PROJECT_ID ?= planet-4-151612

BUILD_IMAGE := $(BUILD_NAMESPACE)/$(GOOGLE_PROJECT_ID)/$(IMAGE_NAME)
export BUILD_IMAGE

BASE_IMAGE_NAME 	?= greenpeaceinternational/circleci-base
BASE_IMAGE_VERSION 	?= latest

BASE_IMAGE := $(BASE_IMAGE_NAME):$(BASE_IMAGE_VERSION)
export BASE_IMAGE

MAINTAINER_NAME 	?= Raymond Walker
MAINTAINER_EMAIL 	?= raymond.walker@greenpeace.org

AUTHOR := $(MAINTAINER_NAME) <$(MAINTAINER_EMAIL)>
export AUTHOR

# ============================================================================

SED_MATCH ?= [^a-zA-Z0-9._-]

ifeq ($(CIRCLECI),true)
# Configure build variables based on CircleCI environment vars
BUILD_NUM = build-$(CIRCLE_BUILD_NUM)
BRANCH_NAME ?= $(shell sed 's/$(SED_MATCH)/-/g' <<< "$(CIRCLE_BRANCH)")
BUILD_TAG ?= $(shell sed 's/$(SED_MATCH)/-/g' <<< "$(CIRCLE_TAG)")
else
# Not in CircleCI environment, try to set sane defaults
BUILD_NUM = build-$(shell uname -n | tr '[:upper:]' '[:lower:]' | sed 's/[^a-zA-Z0-9._-]/-/g')
BRANCH_NAME ?= $(shell git rev-parse --abbrev-ref HEAD | sed 's/$(SED_MATCH)/-/g')
BUILD_TAG ?= $(shell git tag -l --points-at HEAD | tail -n1 | sed 's/$(SED_MATCH)/-/g')
endif

# If BUILD_TAG is blank there's no tag on this commit
ifeq ($(strip $(BUILD_TAG)),)
# Default to branch name
BUILD_TAG := $(BRANCH_NAME)
else
# Consider this the new :latest image
# FIXME: implement build tests before tagging with :latest
PUSH_LATEST := true
endif

REVISION_TAG = $(shell git rev-parse --short HEAD)

# ============================================================================

# Check necessary commands exist

CIRCLECI := $(shell command -v circleci 2> /dev/null)
DOCKER := $(shell command -v docker 2> /dev/null)
YAMLLINT := $(shell command -v yamllint 2> /dev/null)

# ============================================================================

all: init clean build push

init:
	@chmod 755 .githooks/*
	@find .git/hooks -type l -exec rm {} \;
	@find .githooks -type f -exec ln -sf ../../{} .git/hooks/ \;

clean:
	rm -f Dockerfile

lint: lint-yaml lint-docker

lint-yaml:
ifndef YAMLLINT
$(error "yamllint is not installed: https://github.com/adrienverge/yamllint")
endif
	@find . -type f -name '*.yml' | xargs yamllint

lint-docker: Dockerfile
ifndef DOCKER
$(error "docker is not installed: https://docs.docker.com/install/")
endif
	@docker run --rm -i hadolint/hadolint < Dockerfile >/dev/null

pull:
	docker login -u ${DOCKERHUB_USERNAME} -p ${DOCKERHUB_PASSWORD}
	docker pull $(BASE_IMAGE)
	rm -f /home/circleci/.docker/config.json

Dockerfile:
	envsubst '$${BASE_IMAGE},$${AUTHOR}' < Dockerfile.in > $@

build:
ifndef DOCKER
$(error "docker is not installed: https://docs.docker.com/install/")
endif
	$(MAKE) -j lint pull
	docker build \
		--tag=$(BUILD_IMAGE):$(BUILD_TAG) \
		--tag=$(BUILD_IMAGE):$(BUILD_NUM) \
		--tag=$(BUILD_IMAGE):$(REVISION_TAG) \
		.

.PHONY: test
test:
		@$(MAKE) -j1 -C $@ clean
		@$(MAKE) -k -C $@
		$(MAKE) -C $@ status

push: push-tag push-latest

push-tag:
ifndef DOCKER
$(error "docker is not installed: https://docs.docker.com/install/")
endif
	docker push $(BUILD_IMAGE):$(BUILD_TAG)
	docker push $(BUILD_IMAGE):$(BUILD_NUM)

push-latest:
ifndef DOCKER
$(error "docker is not installed: https://docs.docker.com/install/")
endif
	if [[ "$(PUSH_LATEST)" = "true" ]]; then { \
		docker tag $(BUILD_IMAGE):$(REVISION_TAG) $(BUILD_IMAGE):latest; \
		docker push $(BUILD_IMAGE):latest; \
	}	else { \
		echo "Not tagged.. skipping latest"; \
	} fi
