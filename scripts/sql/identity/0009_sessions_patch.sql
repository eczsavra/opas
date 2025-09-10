DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema='auth' AND table_name='sessions' AND column_name='refresh_token'
  ) THEN
    ALTER TABLE auth.sessions ADD COLUMN refresh_token text;
    CREATE UNIQUE INDEX IF NOT EXISTS ux_sessions_refresh_token ON auth.sessions(refresh_token);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema='auth' AND table_name='sessions' AND column_name='ip'
  ) THEN
    ALTER TABLE auth.sessions ADD COLUMN ip inet;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema='auth' AND table_name='sessions' AND column_name='user_agent'
  ) THEN
    ALTER TABLE auth.sessions ADD COLUMN user_agent text;
  END IF;
END $$;
