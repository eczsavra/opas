-- LOGIN: gln + email + password -> (session_id, refresh_token)
CREATE OR REPLACE FUNCTION auth.fn_login_email_password(
  p_gln         text,
  p_email       citext,
  p_password    text,
  p_ip          inet,
  p_user_agent  text
)
RETURNS TABLE (session_id uuid, refresh_token text)
LANGUAGE plpgsql
AS $$
DECLARE
  v_tenant_id uuid;
  v_user_id   uuid;
  v_hash      text;
BEGIN
  SELECT t.id INTO v_tenant_id
  FROM auth.tenants t
  WHERE t.gln = p_gln;

  IF v_tenant_id IS NULL THEN
    RETURN; -- 401
  END IF;

  SELECT u.id, u.password_hash INTO v_user_id, v_hash
  FROM auth.users u
  WHERE u.tenant_id = v_tenant_id
    AND u.email = p_email
  LIMIT 1;

  IF v_user_id IS NULL THEN
    RETURN; -- 401
  END IF;

  IF v_hash IS NULL OR NOT (v_hash = crypt(p_password, v_hash)) THEN
    RETURN; -- 401
  END IF;

  INSERT INTO auth.sessions(tenant_id, user_id, ip, user_agent)
  VALUES (v_tenant_id, v_user_id, p_ip, p_user_agent)
  RETURNING id, refresh_token INTO session_id, refresh_token;

  RETURN NEXT;
END
$$;

-- REFRESH: eski RT -> revoke + yeni session üret (ip text geliyor, inet'e cast ediyoruz)
CREATE OR REPLACE FUNCTION auth.fn_refresh(
  p_refresh_token text,
  p_ip            text,
  p_user_agent    text
)
RETURNS TABLE (session_id uuid, refresh_token text)
LANGUAGE plpgsql
AS $$
DECLARE
  v_old auth.sessions%ROWTYPE;
BEGIN
  SELECT *
    INTO v_old
  FROM auth.sessions s
  WHERE s.refresh_token = p_refresh_token
    AND s.revoked_at IS NULL
    AND s.expires_at > now()
  ORDER BY s.created_at DESC
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN; -- 401
  END IF;

  UPDATE auth.sessions
     SET revoked_at = now()
   WHERE id = v_old.id
     AND revoked_at IS NULL;

  INSERT INTO auth.sessions(tenant_id, user_id, ip, user_agent)
  VALUES (v_old.tenant_id, v_old.user_id, p_ip::inet, p_user_agent)
  RETURNING id, refresh_token INTO session_id, refresh_token;

  RETURN NEXT;
END
$$;

-- CLAIMS: tekil role enum'unu string[] olarak döndür (API string[] bekliyor)
CREATE OR REPLACE FUNCTION auth.fn_session_claims(p_session_id uuid)
RETURNS TABLE (tenant_id uuid, user_id uuid, tenant_gln text, roles text[])
LANGUAGE sql
AS $$
  SELECT t.id,
         u.id,
         t.gln,
         ARRAY[ lower(u.role::text) ]::text[]
  FROM auth.sessions s
  JOIN auth.users   u ON u.id = s.user_id
  JOIN auth.tenants t ON t.id = s.tenant_id
  WHERE s.id = p_session_id
    AND s.revoked_at IS NULL
    AND s.expires_at > now()
  LIMIT 1;
$$;

-- LOGOUT: revoke
CREATE OR REPLACE FUNCTION auth.fn_logout(p_session_id uuid)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
  UPDATE auth.sessions
     SET revoked_at = now()
   WHERE id = p_session_id
     AND revoked_at IS NULL;
END
$$;
