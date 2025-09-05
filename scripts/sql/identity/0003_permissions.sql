-- Şimdilik iskelet (ileride doldururuz)
CREATE TABLE IF NOT EXISTS auth.permissions (
  code        text PRIMARY KEY,
  description text
);

CREATE TABLE IF NOT EXISTS auth.role_permissions (
  role_code text NOT NULL REFERENCES auth.roles(code) ON DELETE CASCADE,
  perm_code text NOT NULL REFERENCES auth.permissions(code) ON DELETE CASCADE,
  PRIMARY KEY(role_code, perm_code)
);
