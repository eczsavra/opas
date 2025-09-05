GRANT USAGE ON SCHEMA auth TO opas_app;

GRANT SELECT ON auth.tenants TO opas_app;
GRANT SELECT ON auth.users   TO opas_app;
GRANT SELECT, INSERT, UPDATE ON auth.sessions TO opas_app;

GRANT EXECUTE ON FUNCTION auth.fn_login_email_password(text,citext,text,inet,text) TO opas_app;
GRANT EXECUTE ON FUNCTION auth.fn_refresh(text,text,text)                            TO opas_app;
GRANT EXECUTE ON FUNCTION auth.fn_session_claims(uuid)                               TO opas_app;
GRANT EXECUTE ON FUNCTION auth.fn_logout(uuid)                                       TO opas_app;
