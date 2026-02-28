ARG BASE_IMAGE=tango-openclaw-base:latest
FROM ${BASE_IMAGE}

USER root
ARG TARGETARCH
RUN GOG_VERSION=$(curl -sL https://api.github.com/repos/steipete/gogcli/releases/latest | grep '"tag_name"' | sed 's/.*"v\(.*\)".*/\1/') && \
    if [ "${TARGETARCH}" = "arm64" ]; then GOG_ARCH="arm64"; else GOG_ARCH="amd64"; fi && \
    curl -fsSL "https://github.com/steipete/gogcli/releases/download/v${GOG_VERSION}/gogcli_${GOG_VERSION}_linux_${GOG_ARCH}.tar.gz" \
    | tar -xz -C /usr/local/bin gog && \
    chmod +x /usr/local/bin/gog
USER node
