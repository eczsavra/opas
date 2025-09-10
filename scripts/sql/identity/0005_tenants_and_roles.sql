-- 0002_tenants_and_roles.sql — tenant-rol eşlemesi (opsiyonel, multi-tenant kısıtlama)
CREATE TABLE IF NOT EXISTS auth.tenant_roles (
tenant_id uuid NOT NULL REFERENCES auth.tenants(id) ON DELETE CASCADE,
role_id uuid NOT NULL REFERENCES auth.roles(id) ON DELETE CASCADE,
PRIMARY KEY(tenant_id, role_id)
);
