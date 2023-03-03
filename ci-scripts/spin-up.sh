#!/bin/sh
spin up \
  --listen 0.0.0.0:3000 \
  --allow-transient-write \
  --from-registry \
    ghcr.io/${GITHUB_ACTOR}/taking-bartholo/oci:${BUILD_ID}
