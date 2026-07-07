-- Amber v2 has no migration workflow, and Granite's built-in migrator can
-- create or drop a model's table but has no versioned migrations, so the
-- schema is plain SQL. Run it with:
--
--   createdb todo_app_dev
--   psql todo_app_dev < db/setup.sql
--
-- The created_at / updated_at columns are required by the `timestamps`
-- macro in src/models/todo.cr.
CREATE TABLE IF NOT EXISTS todos (
  id         BIGSERIAL PRIMARY KEY,
  title      TEXT NOT NULL,
  completed  BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMP,
  updated_at TIMESTAMP
);
