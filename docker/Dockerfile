ARG BASE_IMAGE=tango-openclaw-base:latest
FROM ${BASE_IMAGE}

USER root
ARG TARGETARCH

# Install gog (Google Workspace CLI)
RUN GOG_VERSION=$(curl -sL https://api.github.com/repos/steipete/gogcli/releases/latest | grep '"tag_name"' | sed 's/.*"v\(.*\)".*/\1/') && \
    if [ "${TARGETARCH}" = "arm64" ]; then GOG_ARCH="arm64"; else GOG_ARCH="amd64"; fi && \
    curl -fsSL "https://github.com/steipete/gogcli/releases/download/v${GOG_VERSION}/gogcli_${GOG_VERSION}_linux_${GOG_ARCH}.tar.gz" \
    | tar -xz -C /usr/local/bin gog && \
    chmod +x /usr/local/bin/gog

# Install socat (proxy for Control UI — hardcoded to 127.0.0.1 in OpenClaw)
RUN apt-get update -qq && apt-get install -y -qq --no-install-recommends socat && rm -rf /var/lib/apt/lists/*

USER node
