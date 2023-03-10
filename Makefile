.PHONY: all build-test test version-set chart-ver-set release-app release-chart
.PHONY: test-latest gh-latest-build-id check GH-exists

GITHUB_ACTOR ?= kingdonb

# app version
TAG ?= latest
# chart version
SEMVER ?= 0.0.0-dev

IMAGE ?= ghcr.io/$(GITHUB_ACTOR)/taking-bartholo:$(TAG)
VERSION := $(shell grep -e '^version =' spin.toml | awk '{ print $$3 }' | tr -d '"')
CHART_VER := $(shell grep -e '^version:' charts/bart/Chart.yaml | awk '{ print $$2 }' | tr -d '"')

all: build-test test
build-test:
	docker buildx build --build-arg GITHUB_ACTOR=$(GITHUB_ACTOR) \
		--load . -t $(IMAGE)

release-app:
	git tag $(VERSION)
	git push origin $(VERSION)

release-chart:
	git tag chart-$(CHART_VER)
	git push origin chart-$(CHART_VER)

test:
	docker run -p 3000:3000 --rm --name test -it $(IMAGE)

# Try running `brew install gh` if this errors out
check: GH-exists
GH-exists: ; @which gh > /dev/null

gh-latest-build-id: check
	@set -e ;\
	LAST_RUN=$$(gh run list -L 1 --json databaseId -q .[].databaseId) ;\
	BUILD_ID_JOB=$$(gh run view $$LAST_RUN|grep build-id|awk '{ print $$6 }'|tr -d \)) ;\
	gh run view --job $$BUILD_ID_JOB --log|grep -e 'BUILD_ID=[^$$"]'|grep -v echo |\
		awk '{ print $$4 }' |awk -F= '{ printf "make test TAG=%s", $$2 }'

test-latest:
	`make gh-latest-build-id`

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
