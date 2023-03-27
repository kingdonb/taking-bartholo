#!/usr/bin/env bash
ARCH=$(cat /.csplatform)
# VERSION=2.0.0

set -e -x

if [ -z "${VERSION}" ]; then
  # if [ -n "${TOKEN}" ]; then
  #   VERSION_SLUG=$(curl https://api.github.com/repos/fermyon/spin/releases/latest --silent --location --header "Authorization: token ${TOKEN}" | grep tag_name)
  # else
    # With no GITHUB_TOKEN you will experience occasional failures due to rate limiting
    # Ref: https://github.com/fluxcd/flux2/issues/3509#issuecomment-1400820992
    VERSION_SLUG=$(wget --max-redirect 2 -q -O - https://api.github.com/repos/sigstore/cosign/releases/latest | grep tag_name)
  # fi

  VERSION=$(echo "${VERSION_SLUG}" | sed -E 's/.*"([^"]+)".*/\1/' | cut -c 2-)
fi

BIN_URL="https://github.com/sigstore/cosign/releases/download/v${VERSION}/cosign-linux-${ARCH}"
wget --max-redirect 2 -q "${BIN_URL}" -O /tmp/cosign
install -m 755 /tmp/cosign /usr/local/bin/cosign
