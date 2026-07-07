# The one and only model in this app.
#
# Granite maps this class onto the `todos` table. Amber v2 has no migration
# workflow (Granite's migrator can create/drop a table but has no versioned
# migrations), so you create the table yourself — the exact SQL is in the
# README and in db/setup.sql.
class Todo < Granite::Base
  # `pg` here refers to the connection name we registered with
  # Granite::Connections in src/todo_app.cr — not the database name.
  connection pg
  table todos

  column id : Int64, primary: true
  column title : String
  column completed : Bool = false

  # `timestamps` adds created_at / updated_at columns to the model.
  # The matching TIMESTAMP columns must exist in the table, or saves fail.
  timestamps
end
