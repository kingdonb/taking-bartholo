FROM debian:stable-slim AS builder

ENV platform=aarch64

WORKDIR /opt
RUN apt-get update && apt-get install -y wget && \
  wget https://github.com/fermyon/spin/releases/download/v0.9.0/spin-v0.9.0-linux-${platform}.tar.gz && \
  tar xvf spin-v0.9.0-linux-${platform}.tar.gz && \
  mv spin /usr/local/bin/ && \
  rm spin-v0.9.0-linux-${platform}.tar.gz && \
  rm -rf /var/lib/apt/lists/*

FROM debian:testing-slim AS runner
COPY --from=builder /usr/local/bin/spin /usr/local/bin/spin
WORKDIR /opt
RUN apt-get update && apt-get install -y ca-certificates && \
  rm -rf /var/lib/apt/lists/*
RUN echo "#!/bin/sh\nspin registry pull ghcr.io/kingdonb/taking-bartholo:v1" \
  > spin-pull.sh && chmod +x spin-pull.sh
RUN echo "#!/bin/sh\nspin up --from-registry ghcr.io/kingdonb/taking-bartholo:v1 --listen 0.0.0.0:3000" \
  > spin-up.sh && chmod +x spin-up.sh

CMD ./spin-up.sh
