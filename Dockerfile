ARG BASE_IMAGE=tango-openclaw-base:latest
FROM ${BASE_IMAGE}

USER root
ARG TARGETARCH
RUN if [ "${TARGETARCH}" = "arm64" ]; then GOG_ARCH="arm64"; else GOG_ARCH="x86_64"; fi && \
    curl -fsSL "https://github.com/steipete/gog/releases/latest/download/gog_Linux_${GOG_ARCH}.tar.gz" \
    | tar -xz -C /usr/local/bin && \
    chmod +x /usr/local/bin/gog
USER node
