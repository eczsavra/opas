-- 0011_refresh_rotation.sql
BEGIN;

-- yardımcı kolonlar
ALTER TABLE auth.sessions
  ADD COLUMN IF NOT EXISTS prev_session_id uuid,
  ADD COLUMN IF NOT EXISTS revoked_reason  text;

-- RT benzersiz kalsın
CREATE UNIQUE INDEX IF NOT EXISTS ux_sessions_refresh_token
  ON auth.sessions(refresh_token);

-- eski fonksiyonu kaldır (varsa)
DROP FUNCTION IF EXISTS auth.fn_refresh(text,text,text);

-- tek-kullanımlık refresh: eski session revoke edilir, yeni session + yeni RT döner
CREATE FUNCTION auth.fn_refresh(p_refresh_token text, p_ip text, p_user_agent text)
RETURNS TABLE (session_id uuid, refresh_token text)
LANGUAGE plpgsql
AS $$
DECLARE
  s auth.sessions%ROWTYPE;
BEGIN
  SELECT *
    INTO s
    FROM auth.sessions
   WHERE refresh_token = p_refresh_token
   ORDER BY created_at DESC
   LIMIT 1
   FOR UPDATE;

  IF NOT FOUND THEN
    RETURN; -- yok -> API 401
  END IF;

  IF s.revoked_at IS NOT NULL OR s.expires_at <= now() THEN
    RETURN; -- pasif/expired -> API 401
  END IF;

  UPDATE auth.sessions
     SET revoked_at     = now(),
         revoked_reason = 'rotated'
   WHERE id = s.id;

  RETURN QUERY
  INSERT INTO auth.sessions(
      id, tenant_id, user_id, created_at, expires_at,
      ip, user_agent, refresh_token, prev_session_id
  )
  VALUES(
      gen_random_uuid(), s.tenant_id, s.user_id, now(), now() + interval '30 days',
      p_ip, p_user_agent, gen_random_uuid()::text, s.id
  )
  RETURNING id, refresh_token;
END;
$$;

GRANT EXECUTE ON FUNCTION auth.fn_refresh(text,text,text) TO opas_app;

COMMIT;
