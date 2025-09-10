-- Basit rol tablosu (tekil role alanı buna FK olur)
CREATE TABLE IF NOT EXISTS auth.roles (
  code        text PRIMARY KEY,
  description text
);

INSERT INTO auth.roles(code, description) VALUES
  ('admin','Tenant admin'),
  ('user','Regular user'),
  ('super_admin','Platform super admin')
ON CONFLICT (code) DO NOTHING;

-- users.role -> roles.code FK
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'fk_users_role'
  ) THEN
    ALTER TABLE auth.users
      ADD CONSTRAINT fk_users_role
      FOREIGN KEY(role) REFERENCES auth.roles(code) ON UPDATE CASCADE;
  END IF;
END $$;
