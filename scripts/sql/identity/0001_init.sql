-- Extensions + şema
CREATE EXTENSION IF NOT EXISTS citext;
CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE SCHEMA IF NOT EXISTS auth;

-- Tenants
CREATE TABLE IF NOT EXISTS auth.tenants (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  gln        text NOT NULL UNIQUE,
  name       text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- Users (tekil role alanı)
CREATE TABLE IF NOT EXISTS auth.users (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id     uuid NOT NULL REFERENCES auth.tenants(id) ON DELETE CASCADE,
  email         citext NOT NULL,
  password_hash text   NOT NULL,
  role          text   NOT NULL DEFAULT 'user',
  created_at    timestamptz NOT NULL DEFAULT now(),
  UNIQUE (tenant_id, email)
);

-- Sessions (refresh token rotasyonlu)
CREATE TABLE IF NOT EXISTS auth.sessions (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  refresh_token text NOT NULL UNIQUE,
  created_at    timestamptz NOT NULL DEFAULT now(),
  revoked_at    timestamptz NULL
);

-- Faydalı indexler
CREATE INDEX IF NOT EXISTS ix_users_email        ON auth.users(email);
CREATE INDEX IF NOT EXISTS ix_sessions_user      ON auth.sessions(user_id);
CREATE INDEX IF NOT EXISTS ix_sessions_refresh   ON auth.sessions(refresh_token);
