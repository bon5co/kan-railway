#!/bin/sh
# Kan on Railway: derive the public URLs, migrate, then serve.
set -e

log() { echo "[railway-entrypoint] $*"; }

# --- 1. URLs -----------------------------------------------------------------
# Kan needs to know its own origin. Unset, Better Auth signs cookies for and
# redirects to localhost, so sign-in bounces and invite links are dead. Railway
# only knows the domain at run time, so it is resolved here rather than baked.
if [ -n "$RAILWAY_PUBLIC_DOMAIN" ]; then
  : "${NEXT_PUBLIC_BASE_URL:=https://$RAILWAY_PUBLIC_DOMAIN}"
  : "${BETTER_AUTH_URL:=https://$RAILWAY_PUBLIC_DOMAIN}"
  : "${BETTER_AUTH_TRUSTED_ORIGINS:=https://$RAILWAY_PUBLIC_DOMAIN}"
  export NEXT_PUBLIC_BASE_URL BETTER_AUTH_URL BETTER_AUTH_TRUSTED_ORIGINS
fi
log "base url: ${NEXT_PUBLIC_BASE_URL:-<unset>}"

if [ -z "$BETTER_AUTH_SECRET" ]; then
  log "FATAL: BETTER_AUTH_SECRET is empty. Sessions would be forgeable; refusing to start."
  exit 1
fi

# --- 2. Database -------------------------------------------------------------
# Without POSTGRES_URL, Kan silently falls back to an in-container PGLite file
# and every board is lost on the next redeploy. Fail loudly instead.
if [ -z "$POSTGRES_URL" ]; then
  log "FATAL: POSTGRES_URL is empty. Kan would fall back to ephemeral PGLite storage; refusing to start."
  exit 1
fi

log "waiting for postgres..."
i=0
until node -e '
const { Client } = require("/db/node_modules/pg");
const c = new Client({ connectionString: process.env.POSTGRES_URL });
c.connect().then(() => c.end()).then(() => process.exit(0)).catch(() => process.exit(1));
' 2>/dev/null; do
  i=$((i + 1))
  if [ "$i" -ge 60 ]; then
    log "FATAL: postgres unreachable after 60 attempts"
    exit 1
  fi
  sleep 2
done
log "postgres reachable after $i attempt(s)"

# Upstream runs this as a separate run-once container that Railway would start
# concurrently with the web app. Running it here makes the ordering real.
log "running migrations..."
cd /db && node_modules/.bin/drizzle-kit migrate
log "migrations applied"

# --- 3. Serve ----------------------------------------------------------------
cd /app
log "starting kan on 0.0.0.0:${PORT}"
exec node bootstrap.cjs
