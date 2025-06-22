# Building Caddy

This guide walks you through building your custom Caddy image with DNS challenge support for multiple providers.

## Prerequisites

- Docker installed and running
- DockerHub Account
- Basic understanding of Docker and CI/CD

## Project Structure

Set up your project directory:

```
caddy/
├── Dockerfile
├── README.md
├── .dockerignore
```

## Step 1: Create Dockerfile

Create `Dockerfile` with hybrid build approach for maximum compatibility:

```dockerfile
# Multi-stage build for smaller final image
FROM caddy:2.10-builder AS builder

# Build Caddy with Porkbun and Cloudflare DNS plugins
RUN xcaddy build \
    --with github.com/caddy-dns/porkbun \
    --with github.com/caddy-dns/cloudflare \
    --with github.com/caddyserver/caddy/v2@latest

# Get the working Namecheap binary from CaddyBuilds
FROM ghcr.io/caddybuilds/caddy-namecheap:latest AS namecheap_source

# Final image
FROM caddy:2.10

# Copy Porkbun+base from our build
COPY --from=builder /usr/bin/caddy /tmp/caddy-porkbun

# Copy working Namecheap binary (overwrites with hybrid support)
COPY --from=namecheap_source /usr/bin/caddy /usr/bin/caddy

# Metadata
LABEL maintainer="your@email.com" \
      description="Caddy with Cloudflare, Porkbun and working Namecheap DNS plugins" \
      version="2.10-hybrid" \
      org.opencontainers.image.title="caddy" \
      org.opencontainers.image.description="Caddy web server with DNS challenge plugins" \
      org.opencontainers.image.url="https://hub.docker.com/r/yourusername/caddy" \
      org.opencontainers.image.source="https://github.com/yourusername/caddy" \
      org.opencontainers.image.licenses="Apache-2.0" \
      org.opencontainers.image.vendor="yourusername" \
      org.opencontainers.image.authors="your@email.com"

# Verify plugins are loaded and show available DNS modules
RUN caddy list-modules | grep dns
```

## Step 2: Create .dockerignore

Create `.dockerignore` to exclude unnecessary files:

```
# Git
.git
.gitignore
README.md
LICENSE

# Development files
.env
.env.*
*.log
compose.yaml
docker-compose.yml

# CI/CD
.github
.gitlab-ci.yml

# Documentation
docs/
examples/
```

## Step 3: Local Build and Test

### Build the Image

```bash
# Build for your platform
docker build -t caddy:local .

# Build for multiple architectures (requires buildx)
docker buildx build --platform linux/amd64,linux/arm64,linux/arm/v7 -t caddy:local .
```

### Test the Image

```bash
# Quick test - verify both DNS providers are available
docker run --rm caddy:local caddy version
docker run --rm caddy:local caddy list-modules | grep dns

# Expected output should include:
# dns.providers.cloudflare
# dns.providers.namecheap
# dns.providers.porkbun

# Full test with compose
cat << EOF > test-compose.yaml
version: '3.8'
services:
  caddy:
    image: caddy:local
    ports:
      - "80:80"
    volumes:
      - ./test-Caddyfile:/etc/caddy/Caddyfile:ro
volumes:
  caddy_data:
EOF

# Create test Caddyfile
echo ":80 { respond \"Hello from Caddy DNS!\" }" > test-Caddyfile

# Test
docker compose -f test-compose.yaml up -d
curl localhost:8080
docker compose -f test-compose.yaml down

# Cleanup
rm test-compose.yaml test-Caddyfile
```

## Supported DNS Providers

This image includes working implementations of:

- ✅ **Cloudflare** - Full support with Caddy 2.10
- ✅ **Namecheap** - Full support (via CaddyBuilds hybrid approach)
- ✅ **Porkbun** - Full support with Caddy 2.10

### Why This Hybrid Approach?

The official `caddy-dns/namecheap` plugin is currently broken due to libdns 1.0 API changes. This image uses a proven working implementation from CaddyBuilds while maintaining both Porkbun and Cloudflare support through a custom build.

## Architecture Support

This image is built for multiple architectures:

- `linux/amd64` - Standard x86_64 systems
- `linux/arm64` - ARM64 systems (Apple M1/M2, modern ARM servers)
- `linux/arm/v7` - Raspberry Pi and ARM v7 devices

## Step 4: Set Up Multi-Architecture Builds

### Enable Docker Buildx

```bash
# Create and use new builder
docker buildx create --name multiarch --use
docker buildx inspect --bootstrap

# Verify supported platforms
docker buildx ls
```

### Build Multi-Architecture Image

```bash
# Build for multiple platforms
docker buildx build \
  --platform linux/amd64,linux/arm64,linux/arm/v7 \
  --tag yourusername/caddy:latest \
  --tag yourusername/caddy:2.10 \
  --tag yourusername/caddy:2.10-hybrid \
  --push \
  .
```

## Step 5: Manual Publishing to Docker Hub

### Login to Docker Hub

```bash
# Login with your credentials
docker login

# Or use token (recommended for CI/CD)
echo $DOCKER_TOKEN | docker login --username yourusername --password-stdin
```

### Tag and Push

```bash
# Tag your image
docker tag caddy:local yourusername/caddy:latest
docker tag caddy:local yourusername/caddy:2.10-hybrid
docker tag caddy:local yourusername/caddy:2.10

# Push to Docker Hub
docker push yourusername/caddy:latest
docker push yourusername/caddy:2.10-hybrid
docker push yourusername/caddy:2.10
```

## Usage Examples

### Docker Compose

```yaml
version: '3.8'

services:
  caddy:
    container_name: caddy
    image: yourusername/caddy:latest
    restart: unless-stopped

    # User directive goes here at service level, not in environment
    user: "${UID:-1000}:${GID:-1000}"

    cap_add:
      - NET_ADMIN

    ports:
      - "80:80"
      - "443:443"
      - "443:443/udp"

    environment:
      # Only environment variables go here
      # Cloudflare credentials
      - CLOUDFLARE_API_TOKEN=${CLOUDFLARE_API_TOKEN}

      # Namecheap credentials
      - NAMECHEAP_API_KEY=${NAMECHEAP_API_KEY}
      - NAMECHEAP_API_USER=${NAMECHEAP_API_USER}
      - NAMECHEAP_CLIENT_IP=${NAMECHEAP_CLIENT_IP}

      # Porkbun credentials
      - PORKBUN_API_KEY=${PORKBUN_API_KEY}
      - PORKBUN_SECRET_KEY=${PORKBUN_SECRET_KEY}

    volumes:
      # Configuration
      - ./config/Caddyfile:/etc/caddy/Caddyfile:ro

      # Website content
      - ./sites:/srv:ro

      # Logs (writable)
      - ./logs:/var/log/caddy:rw

      # Caddy data (certificates, etc.)
      - ./data:/data:rw

      # Caddy config (internal state)
      - ./caddy-config:/config:rw
```

#### Caddyfile Example

```caddyfile
{
    # Global configuration
    admin off
}

# Reusable logging snippet
(logging) {
    log {
    output file /var/log/caddy/access.log {
        roll_size 10MB
        roll_keep 5
    }
    format json
    level INFO
    }
}

(security_headers) {
    header {
        X-Content-Type-Options nosniff
        X-Frame-Options DENY
        X-XSS-Protection "1; mode=block"
        Referrer-Policy strict-origin-when-cross-origin
        Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
    }
}

(namecheap_ssl) {
    tls {
        dns namecheap {
            api_key {env.NAMECHEAP_API_KEY}
            user {env.NAMECHEAP_API_USER}
            client_ip {env.NAMECHEAP_CLIENT_IP}
            api_endpoint https://api.namecheap.com/xml.response
        }
        resolvers 1.1.1.1 1.0.0.1
    }
}

(porkbun_ssl) {
    tls {
        dns porkbun {
            api_key {env.PORKBUN_API_KEY}
            api_secret_key {env.PORKBUN_SECRET_KEY}
        }
        resolvers 1.1.1.1 1.0.0.1
    }
}

# Catch-all for undefined sites
* {
    import logging
    respond "YOU SHALL NOT PASS!" 403
}

# Wildcard domain configuration
*.domain.net {
    import logging
    import security_headers
    import namecheap_ssl
    import porkbun_ssl

    @app host app.domain.net
    handle @app {
        reverse_proxy 192.168.0.1:1234
    }

    # Handle other subdomains
    handle {
        respond "Not all who wander are lost" 404
    }
}
```

## Environment Variables

### Cloudflare Configuration

```bash
CLOUDFLARE_API_TOKEN=your_api_token_here
```

### Namecheap Configuration

```bash
NAMECHEAP_API_KEY=your_api_key_here
NAMECHEAP_API_USER=your_username_here
NAMECHEAP_CLIENT_IP=your_whitelisted_ip_here
```

### Porkbun Configuration

```bash
PORKBUN_API_KEY=your_api_key_here
PORKBUN_SECRET_KEY=your_secret_key_here
```

## Troubleshooting

### DNS Provider Issues

```bash
# Verify plugins are loaded
docker run --rm yourusername/caddy:latest caddy list-modules | grep dns

# Expected output:
# dns.providers.cloudflare
# dns.providers.namecheap
# dns.providers.porkbun

# Test DNS connectivity
docker run --rm yourusername/caddy:latest nslookup example.com 1.1.1.1
```

### Build Failures

```bash
# Check build logs
docker buildx build --progress=plain .

# Test individual stages
docker build --target builder -t test-builder .
docker run --rm test-builder xcaddy version
```

### Multi-Architecture Issues

```bash
# Inspect manifest
docker buildx imagetools inspect yourusername/caddy:latest

# Test specific architecture
docker run --platform linux/arm64 --rm yourusername/caddy:latest caddy version
```

## Known Limitations

1. **Namecheap Plugin**: Uses a third-party implementation due to upstream libdns compatibility issues
2. **Plugin Mixing**: The hybrid approach may have limitations with certain plugin combinations
3. **Updates**: Namecheap support depends on the CaddyBuilds project maintenance

## License

This project is licensed under the Apache-2.0 License - see the [LICENSE](LICENSE) file for details.

## Support

- [Caddy Documentation](https://caddyserver.com/docs/)
- [Cloudflare API Documentation](https://developers.cloudflare.com/fundamentals/api/)
- [Namecheap API Documentation](https://www.namecheap.com/support/api/)
- [Porkbun API Documentation](https://porkbun.com/api/json/v3/documentation)
- [Issue Tracker](https://github.com/yourusername/caddy/issues)

---