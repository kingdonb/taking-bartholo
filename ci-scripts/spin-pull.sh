#!/bin/sh
spin registry pull \
  ghcr.io/${GITHUB_ACTOR}/taking-bartholo/oci:${BUILD_ID}
