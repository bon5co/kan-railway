# Wrapper over Kan's official images, both pinned by digest.
#
# Upstream ships Kan as TWO containers: `kan` (the Next.js web app, distroless,
# no shell) and `kan-migrate` (a run-once drizzle-kit container). On Railway a
# run-once container is a poor fit -- services start concurrently, so the web
# app races the migration on first boot, and the migrate service then sits in
# the deployer's project forever with nothing to do.
#
# This image runs the migration inside the web container's own entrypoint,
# before the server starts, and derives every URL Kan needs from
# RAILWAY_PUBLIC_DOMAIN so nothing points at localhost.

# --- migration tooling, built against glibc to match the web image ----------
FROM node:20-bookworm-slim AS migrate

WORKDIR /db

COPY --from=ghcr.io/kanbn/kan-migrate:0.6.0@sha256:3296fd28e037a93dda478981494a72c6905ecd4f0d0739e79139172844acbc4b /db/migrations ./migrations

# Upstream's drizzle.config.ts hardcodes `ssl: NODE_ENV === "production"`, which
# fails against a plain Postgres on Railway's private network. Traffic between
# services never leaves the project, so SSL is not required here.
COPY drizzle.config.ts ./drizzle.config.ts

RUN npm init -y >/dev/null && \
    npm install --save-exact --no-audit --no-fund \
      drizzle-kit@0.30.6 drizzle-orm@0.41.0 pg@8.14.1 && \
    npm cache clean --force

# --- runtime ---------------------------------------------------------------
FROM node:20-bookworm-slim

WORKDIR /app

COPY --from=ghcr.io/kanbn/kan:0.6.0@sha256:0087a72a123d8462c66ddce3a303049d4ec92f03cfba297d41466605ef8cb5b5 /app /app
COPY --from=migrate /db /db

COPY railway-entrypoint.sh /usr/local/bin/railway-entrypoint.sh
RUN chmod +x /usr/local/bin/railway-entrypoint.sh && \
    chown -R 1000:1000 /app /db

ENV NODE_ENV=production \
    HOSTNAME=0.0.0.0 \
    PORT=3000

USER 1000:1000

EXPOSE 3000
ENTRYPOINT ["/usr/local/bin/railway-entrypoint.sh"]
