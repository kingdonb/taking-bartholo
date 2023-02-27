.PHONY: all build-test test

IMAGE ?= ghcr.io/kingdonb/taking-bartholo:test

all: build-test test
build-test:
	docker build . -t $(IMAGE)

test:
	docker run -p 3000:3000 --rm --name test -it $(IMAGE) sh
