-- Rol ekleme/güncelleme yardımcı fonksiyonu
CREATE OR REPLACE FUNCTION auth.fn_role_add(p_code text, p_description text DEFAULT NULL)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  INSERT INTO auth.roles(code, description) VALUES (p_code, p_description)
  ON CONFLICT (code) DO UPDATE SET description = EXCLUDED.description;
END;
$$;

GRANT EXECUTE ON FUNCTION auth.fn_role_add(text, text) TO opas_app;
