# 0005 — .env.example mirrors compose defaults; all image tags parameterized

**Date:** 2026-07-04 · **Issue:** #4

## Decided

1. `.env.example` documents **every** `${VAR}` referenced in `docker-compose.yml`,
   with values identical to the compose-side `:-default`s — so `cp .env.example .env`
   and no `.env` at all produce byte-identical rendered config. Verified with
   `docker compose --profile core --profile quality --profile tools config`.
2. The issue scope ("ports, image tags, credentials" as tunables) was read as: image
   tags that were still literals (`postgres:16-alpine`, `adminer:latest`) get
   parameterized too → `POSTGRES_TAG`, `ADMINER_TAG`, defaults preserved. Zero
   behavior change; human was AFK so the recommended option was taken autonomously.
3. Cross-repo note stays in the file itself: `POSTGRES_PORT=5432` is the
   feature_flag contract; per-service credentials (`ff_user`, `sonar`) come from
   `postgres/init/` SQL, **not** env vars — `.env.example` says so to prevent
   someone "fixing" credentials in the wrong layer.

## Verification recipe

```bash
cp .env.example .env && docker compose --profile core --profile quality --profile tools config -q
grep -oE '\$\{[A-Z_]+' docker-compose.yml | sort -u   # must equal the keys in .env.example
```
