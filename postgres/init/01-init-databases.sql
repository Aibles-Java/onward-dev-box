-- 01-init-databases.sql — per-service databases and owner users for the shared
-- Postgres instance (docs/INFRASTRUCTURE.md §1.2). Executed by the Postgres
-- entrypoint ONLY on first boot (empty volume) — see CLAUDE.md gotchas. Written
-- idempotently so it can also be applied by hand to a live instance:
--   docker compose exec -T postgres psql -U postgres -f - < postgres/init/01-init-databases.sql
--
-- Credentials are local-only by design (CLAUDE.md gotchas). ff_user/ff_password/
-- feature_flag_db are the cross-repo contract with ../feature_flag's
-- application.properties — do not change them here without a matching change there.

-- feature_flag service ---------------------------------------------------------
DO $$
BEGIN
   IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'ff_user') THEN
      CREATE ROLE ff_user LOGIN PASSWORD 'ff_password';
   END IF;
END
$$;

SELECT 'CREATE DATABASE feature_flag_db OWNER ff_user'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'feature_flag_db')\gexec

-- SonarQube (quality profile) --------------------------------------------------
DO $$
BEGIN
   IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'sonar') THEN
      CREATE ROLE sonar LOGIN PASSWORD 'sonar_password';
   END IF;
END
$$;

SELECT 'CREATE DATABASE sonar OWNER sonar'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'sonar')\gexec
