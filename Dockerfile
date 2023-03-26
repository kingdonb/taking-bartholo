ARG BUILD_ID=canary
ARG GITHUB_ACTOR
FROM debian:bookworm-slim AS builder

ENV spin_ver=1.0.0
ARG TARGETARCH

COPY ci-scripts/platform.sh .
RUN ./platform.sh

WORKDIR /opt
RUN apt-get update && apt-get install -y wget && \
  wget -q https://github.com/fermyon/spin/releases/download/v${spin_ver}/spin-v${spin_ver}-linux-$(cat /.platform).tar.gz && \
  tar xvf spin-v${spin_ver}-linux-$(cat /.platform).tar.gz && \
  mv spin /usr/local/bin/ && \
  rm spin-v${spin_ver}-linux-$(cat /.platform).tar.gz && \
  rm -rf /var/lib/apt/lists/*

FROM debian:bookworm-slim AS runner
COPY --from=builder /usr/local/bin/spin /usr/local/bin/spin
WORKDIR /opt
RUN apt-get update && apt-get install -y ca-certificates && \
  rm -rf /var/lib/apt/lists/*
ADD ci-scripts/spin-pull.sh \
  ci-scripts/spin-up.sh \
    /usr/local/bin/

RUN bash -c "chmod +x /usr/local/bin/spin-{up,pull}.sh"

ARG BUILD_ID
ARG GITHUB_ACTOR
RUN echo "BUILD_ID=$BUILD_ID" > /env.vars \
 && echo "GITHUB_ACTOR=$GITHUB_ACTOR" >> /env.vars

CMD bash -c "set -a && source /env.vars && spin-up.sh"
