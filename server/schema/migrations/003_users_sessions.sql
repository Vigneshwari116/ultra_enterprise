-- Users and login sessions. Idempotent: safe to run more than once.
-- Does not change bill formats, numbering, or posting.
--
-- Apply on the VPS (use the database in DATABASE_URL; do not point this at
-- ultra_enterprise):
--   psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f server/schema/migrations/003_users_sessions.sql
--
-- From the server directory:
--   psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f schema/migrations/003_users_sessions.sql

SET search_path TO public;

CREATE TABLE IF NOT EXISTS public.app_users (
  id            BIGSERIAL PRIMARY KEY,
  username      TEXT NOT NULL,
  name          TEXT NOT NULL,
  password_hash TEXT NOT NULL,
  role          TEXT NOT NULL CHECK (role IN ('superuser', 'admin', 'user')),
  is_active     BOOLEAN NOT NULL DEFAULT TRUE,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS app_users_username_lower_idx
  ON public.app_users (LOWER(username));

CREATE TABLE IF NOT EXISTS public.app_sessions (
  id            UUID PRIMARY KEY,
  user_id       BIGINT NOT NULL REFERENCES public.app_users (id),
  token_hash    TEXT NOT NULL,
  device_name   TEXT,
  ip_address    TEXT,
  login_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  last_activity TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  logout_at     TIMESTAMPTZ,
  is_active     BOOLEAN NOT NULL DEFAULT TRUE,
  logout_reason TEXT CHECK (
    logout_reason IS NULL
    OR logout_reason IN ('user', 'admin', 'disabled', 'expired')
  )
);

CREATE UNIQUE INDEX IF NOT EXISTS app_sessions_token_hash_idx
  ON public.app_sessions (token_hash);

CREATE INDEX IF NOT EXISTS app_sessions_user_active_idx
  ON public.app_sessions (user_id, is_active);

CREATE INDEX IF NOT EXISTS app_sessions_last_activity_idx
  ON public.app_sessions (last_activity);
