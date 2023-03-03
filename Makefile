.PHONY: all build-test test

GITHUB_ACTOR ?= kingdonb
IMAGE ?= ghcr.io/$(GITHUB_ACTOR)/taking-bartholo:test

all: build-test test
build-test:
	docker buildx build --build-arg GITHUB_ACTOR=$(GITHUB_ACTOR) \
		--load . -t $(IMAGE)

test:
	docker run -p 3000:3000 --rm --name test -it $(IMAGE) sh
