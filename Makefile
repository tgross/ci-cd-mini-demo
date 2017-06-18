# Makefile for shipping and testing the container image.

MAKEFLAGS += --warn-undefined-variables
.DEFAULT_GOAL := build
.PHONY: *

# we get these from CI environment if available, otherwise from git
GIT_COMMIT ?= $(shell git rev-parse --short HEAD)
GIT_BRANCH ?= $(shell git rev-parse --abbrev-ref HEAD)
WORKSPACE ?= $(shell pwd)
VERSION ?= dev-build-not-for-release

namespace ?= 0x74696d
tag := $(shell basename $(GIT_BRANCH))
image := $(namespace)/app

## Display this help message
help:
	@awk '/^##.*$$/,/[a-zA-Z_-]+:/' $(MAKEFILE_LIST) | awk '!(NR%2){print $$0p}{p=$$0}' | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}' | sort

# ------------------------------------------------
# Container builds

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
