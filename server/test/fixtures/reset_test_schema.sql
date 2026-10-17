-- Destructive reset for integration tests only. Requires database name ending in _test.
DROP SCHEMA IF EXISTS public CASCADE;
CREATE SCHEMA public;
GRANT ALL ON SCHEMA public TO public;
