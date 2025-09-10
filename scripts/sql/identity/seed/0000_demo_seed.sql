DO $$
DECLARE v_t uuid;
BEGIN
  -- tenant upsert by gln
  IF NOT EXISTS (SELECT 1 FROM auth.tenants WHERE gln='8690000000001') THEN
    INSERT INTO auth.tenants(gln, name) VALUES ('8690000000001','Demo Tenant') RETURNING id INTO v_t;
  ELSE
    SELECT id INTO v_t FROM auth.tenants WHERE gln='8690000000001';
    UPDATE auth.tenants SET name='Demo Tenant' WHERE id=v_t;
  END IF;

  -- user upsert by email (tek rol: admin)
  IF NOT EXISTS (SELECT 1 FROM auth.users WHERE email='demo@opas.local') THEN
    INSERT INTO auth.users(tenant_id, email, password_hash, roles)
    VALUES (v_t, 'demo@opas.local', crypt('opas123!', gen_salt('bf')), ARRAY['admin']);
  ELSE
    UPDATE auth.users
       SET tenant_id = v_t,
           password_hash = crypt('opas123!', gen_salt('bf')),
           roles = ARRAY['admin']
     WHERE email='demo@opas.local';
  END IF;
END $$;
