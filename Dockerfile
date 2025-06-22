# Use a working Namecheap image as base
FROM caddy:2.10-builder AS builder

# Build Caddy with both Porkbun and a working Namecheap implementation
RUN xcaddy build \
    --with github.com/caddy-dns/cloudflare \
    --with github.com/caddy-dns/porkbun \
    --with github.com/caddyserver/caddy/v2@latest

# Get the working Namecheap binary from CaddyBuilds
FROM ghcr.io/caddybuilds/caddy-namecheap:latest AS namecheap_source

# Final image
FROM caddy:2.10

# Copy Porkbun+base from our build
COPY --from=builder /usr/bin/caddy /tmp/caddy-porkbun

# Copy working Namecheap binary
COPY --from=namecheap_source /usr/bin/caddy /usr/bin/caddy

# Metadata
LABEL maintainer="root@n4s.dev" \
    description="Caddy with Porkbun and working Namecheap DNS plugins" \
    version="hybrid" \
    org.opencontainers.image.title="caddy" \
    org.opencontainers.image.description="Caddy web server with DNS challenge plugins" \
    org.opencontainers.image.url="https://hub.docker.com/r/need4swede/caddy" \
    org.opencontainers.image.source="https://github.com/need4swede/caddy" \
    org.opencontainers.image.licenses="Apache-2.0" \
    org.opencontainers.image.vendor="need4swede" \
    org.opencontainers.image.authors="root@n4s.dev"

# Note: This gives you Namecheap for sure, but you'll need to test if Porkbun is included
RUN caddy list-modules | grep dns