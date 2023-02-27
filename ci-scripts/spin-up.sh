#!/bin/sh
spin up \
  --listen 0.0.0.0:3000 \
  --allow-transient-write \
  --from-registry \
    ghcr.io/kingdonb/taking-bartholo:v1
