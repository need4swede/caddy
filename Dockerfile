# Use the LATEST Caddy builder to get a modern Go toolchain.
FROM caddy:2.10-builder AS builder

# Build Caddy v2.9.1, which is required by the working Namecheap plugin,
# with the full set of verified plugins.
RUN xcaddy build v2.9.1 \
    --with github.com/caddy-dns/namecheap \
    --with github.com/caddy-dns/porkbun@v0.2.1 \
    --with github.com/caddy-dns/cloudflare@7b8ded4 \
    --with github.com/porech/caddy-maxmind-geolocation

# Final, clean image based on the required Caddy version (2.9.1).
FROM caddy:2.9.1

# Copy the Caddy binary that was custom-built with your plugins
COPY --from=builder /usr/bin/caddy /usr/bin/caddy

# Metadata
LABEL maintainer="yourusername@email.com" \
    description="Caddy v2.9.1 with Cloudflare, Porkbun, Namecheap and Maxmind Geo-Filtering" \
    version="2.9.1" \
    org.opencontainers.image.title="caddy" \
    org.opencontainers.image.description="Caddy v2.9.1 with Cloudflare, Porkbun, Namecheap and Maxmind Geo-Filtering" \
    org.opencontainers.image.url="https://hub.docker.com/r/yourusername/caddy" \
    org.opencontainers.image.source="https://github.com/yourusername/caddy" \
    org.opencontainers.image.licenses="Apache-2.0" \
    org.opencontainers.image.vendor="yourusername" \
    org.opencontainers.image.authors="yourusername@email.com"

# Verify that all your specified modules are loaded successfully
RUN caddy list-modules --versions