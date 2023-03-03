ARG BUILD_ID=canary
FROM debian:stable-slim AS builder

ENV spin_ver=0.10.0
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

FROM debian:testing-slim AS runner
COPY --from=builder /usr/local/bin/spin /usr/local/bin/spin
WORKDIR /opt
RUN apt-get update && apt-get install -y ca-certificates && \
  rm -rf /var/lib/apt/lists/*
ARG BUILD_ID

RUN echo "BUILD_ID=$BUILD_ID" >> /env.vars
ADD ci-scripts/spin-pull.sh \
  ci-scripts/spin-up.sh \
    /usr/local/bin/

RUN bash -c "chmod +x /usr/local/bin/spin-{up,pull}.sh"

CMD bash -c "source /env.vars && export BUILD_ID && spin-up.sh"
