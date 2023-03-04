.PHONY: all build-test test version-set chart-ver-set

GITHUB_ACTOR ?= kingdonb
TAG ?= latest # app version
SEMVER ?= 0.0.0-dev # chart version
IMAGE ?= ghcr.io/$(GITHUB_ACTOR)/taking-bartholo:$(TAG)
VERSION := $(shell grep -e '^version =' spin.toml | awk '{ print $$3 }' | tr -d '"')
CHART_VER := $(shell grep -e '^version:' charts/bart/Chart.yaml | awk '{ print $$2 }' | tr -d '"')

all: build-test test
build-test:
	docker buildx build --build-arg GITHUB_ACTOR=$(GITHUB_ACTOR) \
		--load . -t $(IMAGE)

test:
	docker run -p 3000:3000 --rm --name test -it $(IMAGE) sh

version-set:
	@next="$(TAG)" && \
	current="$(VERSION)" && \
	/usr/bin/sed -i '' "s/version = \"$$current\"/version = \"$$next\"/g" spin.toml && \
	/usr/bin/sed -i '' "s/^appVersion: \"$$current\"/appVersion: \"$$next\"/g" charts/bart/Chart.yaml && \
	/usr/bin/sed -i '' "s/^  tag: $$current/  tag: $$next/g" charts/bart/values.yaml

chart-ver-set:
	@next="$(SEMVER)" && \
	current="$(CHART_VER)" && \
	/usr/bin/sed -i '' "s/^version: $$current/version: $$next/g" charts/bart/Chart.yaml
