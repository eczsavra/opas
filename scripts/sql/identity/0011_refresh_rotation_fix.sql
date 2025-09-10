-- 0011_refresh_rotation_fix.sql
BEGIN;

-- yardımcı kolonlar & indeks (idempotent)
ALTER TABLE auth.sessions
  ADD COLUMN IF NOT EXISTS prev_session_id uuid,
  ADD COLUMN IF NOT EXISTS revoked_reason  text;

CREATE UNIQUE INDEX IF NOT EXISTS ux_sessions_refresh_token
  ON auth.sessions(refresh_token);

-- eski tanım varsa kaldır
DROP FUNCTION IF EXISTS auth.fn_refresh(text,text,text);

-- tek-kullanımlık refresh (OUT param adı "refresh_token" kalsın)
CREATE FUNCTION auth.fn_refresh(p_refresh_token text, p_ip text, p_user_agent text)
RETURNS TABLE (session_id uuid, refresh_token text)
LANGUAGE plpgsql
AS $$
DECLARE
  s auth.sessions%ROWTYPE;
BEGIN
  -- 1) RT'yi bul (alias ile tam nitelikli)
  SELECT *
    INTO s
    FROM auth.sessions se
   WHERE se.refresh_token = p_refresh_token
   ORDER BY se.created_at DESC
   LIMIT 1
   FOR UPDATE;

  IF NOT FOUND THEN
    RETURN; -- yok -> API 401
  END IF;

  -- pasif/expired ise yine 0 satır
  IF s.revoked_at IS NOT NULL OR s.expires_at <= now() THEN
    RETURN;
  END IF;

  -- 2) Eski session revoke
  UPDATE auth.sessions
     SET revoked_at     = now(),
         revoked_reason = 'rotated'
   WHERE id = s.id;

  -- 3) Yeni session + yeni RT üret ve güvenli biçimde döndür
  RETURN QUERY
  WITH ins AS (
    INSERT INTO auth.sessions(
      id, tenant_id, user_id, created_at, expires_at,
      ip, user_agent, refresh_token, prev_session_id
    )
    VALUES (
      gen_random_uuid(), s.tenant_id, s.user_id, now(), now() + interval '30 days',
      p_ip, p_user_agent, gen_random_uuid()::text, s.id
    )
    RETURNING id, refresh_token
  )
  SELECT ins.id, ins.refresh_token FROM ins;
END;
$$;

GRANT EXECUTE ON FUNCTION auth.fn_refresh(text,text,text) TO opas_app;

COMMIT;
