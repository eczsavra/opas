-- 0004_tenants.sql — tenant yardımcı fonksiyonları
DROP FUNCTION IF EXISTS auth.fn_tenant_upsert(text);
CREATE FUNCTION auth.fn_tenant_upsert(p_gln text)
RETURNS uuid
LANGUAGE plpgsql AS $$
DECLARE v_id uuid;
BEGIN
SELECT id INTO v_id FROM auth.tenants WHERE gln = p_gln;
IF v_id IS NULL THEN
INSERT INTO auth.tenants(gln) VALUES (p_gln) RETURNING id INTO v_id;
END IF;
RETURN v_id;
END $$;
