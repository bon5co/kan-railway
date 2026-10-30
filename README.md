# kan-railway

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/kan-or-just-updated-trello-alternative-y?referralCode=Z1xivh&utm_medium=integration&utm_source=template&utm_campaign=generic)

**Deploy on Railway:** [Kan template](https://railway.com/deploy/kan-or-just-updated-trello-alternative-y?referralCode=Z1xivh&utm_medium=integration&utm_source=template&utm_campaign=generic)

Wrapper image over [Kan](https://github.com/kanbn/kan) for Railway, built for the
`Kan | (Just Updated) Trello Alternative You Can Actually Sign Into` template.

Both upstream images are pinned by digest:

- `ghcr.io/kanbn/kan:0.6.0` — the Next.js web app (distroless).
- `ghcr.io/kanbn/kan-migrate:0.6.0` — the drizzle migrations (files only; the
  drizzle-kit toolchain is reinstalled here against glibc to match the web image).

## What this changes

1. **Migrations run in the app container, before the server starts.** Upstream
   models the migration as a separate run-once container. Railway starts every
   service in a project concurrently, so a template that keeps them separate
   races its own schema on first boot and leaves a finished job container in the
   project forever.
2. **Public URLs are derived from `RAILWAY_PUBLIC_DOMAIN` at run time.** Without
   them Better Auth signs cookies for `localhost` and invite links are dead.
   Explicitly-set values win, so a custom domain still works.
3. **`drizzle.config.ts` no longer forces TLS.** Upstream hardcodes
   `ssl: NODE_ENV === "production"`, which cannot connect to a plain Postgres on
   Railway's project-private network. Set `POSTGRES_SSL=true` to restore it.
4. **Two silent-data-loss modes became refusals.** Empty `POSTGRES_URL` (Kan
   falls back to ephemeral in-container PGLite) and empty `BETTER_AUTH_SECRET`
   (forgeable sessions) both exit with a named error instead of booting.

## What it does not change

Sign-in configuration is left to the template's variables, not baked here.
Note that Kan disables email/password sign-in unless
`NEXT_PUBLIC_ALLOW_CREDENTIALS=true`
([`packages/auth/src/auth.ts`](https://github.com/kanbn/kan/blob/main/packages/auth/src/auth.ts)),
and only registers social providers whose `*_CLIENT_ID`/`*_CLIENT_SECRET` pair is
non-empty — so a deploy that sets neither has no way to sign in at all.
