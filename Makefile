# Makefile for shipping and testing the container image.

MAKEFLAGS += --warn-undefined-variables
.DEFAULT_GOAL := build
.PHONY: *

# we get these from CI environment if available, otherwise from git
GIT_COMMIT ?= $(shell git rev-parse --short HEAD)
GIT_BRANCH ?= $(shell git rev-parse --abbrev-ref HEAD)
WORKSPACE ?= $(shell pwd)

namespace ?= 0x74696d
tag ?= $(shell basename $(GIT_BRANCH))
image := $(namespace)/app

## Display this help message
help:
	@awk '/^##.*$$/,/[a-zA-Z_-]+:/' $(MAKEFILE_LIST) | awk '!(NR%2){print $$0p}{p=$$0}' | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}' | sort

# ------------------------------------------------
# Container builds

VERSION ?= dev-build-not-for-release

## Builds the application container image
build:
	docker build -t=$(image):$(tag) .

## Push the current application container images to the Docker registry
push:
	docker push $(image):$(tag)

## Push a version number to a specific Docker image tag ('VERSION=xxx make release')
release:
	docker tag $(image):$(tag) $(image):$(VERSION)
	docker push $(image):$(VERSION)


# ------------------------------------------------
# Infrastructure

INSTANCES ?= 3
CONTAINERS ?= 6

# note that the create-stack below assumes that we've already set up the
# VPC and subnets, ssh keys, IAM roles, etc.

## Launches an ECS stack; uses the branch as part of the name of the stack
create-stack:
	aws cloudformation create-stack \
		--stack-name app-$(tag) \
		--disable-rollback \
		--template-body file://infra/ecs.yml \
		--parameters ParameterKey=ContainerImage,ParameterValue=$(image):$(tag) \
		--tags $(tag)

## Updates the container on our ECS stack
update-stack:
	aws cloudformation update-stack \
		--stack-name app-$(tag) \
		--disable-rollback \
		--template-body file://infra/ecs.yml \
		--parameters ParameterKey=ContainerImage,ParameterValue=$(image):$(tag) \
		ParameterKey=DesiredCapacity,ParameterValue=$(INSTANCES) \
		--tags $(tag)

## Increase the number of containers for app
scale-app:
	aws update-service \
		--cluster app-$(tag) \
		--service app \
		--desired-count $(CONTAINERS)

# ------------------------------------------------
# Development

## Runs the app image in a local Docker container with your source code mounted to it.
run:
	docker run -d -p 5000:5000 --name app \
		-v $(WORKSPACE)/src:/src \
		-v $(WORKSPACE)/db:/db \
		$(image):$(tag) python /src/app.py

## Loads the schema in the local Docker container image.
schema:
	docker exec -i app sqlite3 /db/database.db < db/schema.sql

## Run the unit tests in a local Docker container with your source code mounted to it.
test:
	docker run -it \
		-v $(WORKSPACE)/src:/src \
		$(image):$(tag) python /src/test.py
