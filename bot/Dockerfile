FROM node:22-bookworm-slim

RUN apt-get update && \
    apt-get install -y --no-install-recommends git curl jq ripgrep && \
    rm -rf /var/lib/apt/lists/*

RUN corepack enable

WORKDIR /app

COPY package.json pnpm-lock.yaml ./
RUN pnpm install --frozen-lockfile --prod

COPY dist/ ./dist/

USER node

CMD ["node", "dist/index.js"]
