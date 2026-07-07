require "amber"
require "granite"
require "granite/adapter/pg"

# Register the database connection BEFORE any model class is required.
# Granite resolves `connection pg` in the model at require time, so this
# line has to come first or you get "no connection registered" errors.
Granite::Connections << Granite::Adapter::Pg.new(
  name: "pg",
  url: ENV["DATABASE_URL"]? || "postgres://localhost/todo_app_dev"
)

require "./models/todo"
require "./controllers/todos_controller"
require "./assets"

Amber::Server.configure do
  # The :web pipeline runs before every route mounted under `routes :web`.
  pipeline :web do
    plug Amber::Pipe::Error.new
    plug Amber::Pipe::Logger.new
    plug Amber::Pipe::Session.new # CSRF stores its token in the session,
    plug Amber::Pipe::Flash.new   # and Flash needs Session too.
    plug Amber::Pipe::CSRF.new
  end

  # Static files need their OWN pipeline + a catch-all route below.
  # Plugging Amber::Pipe::Static into :web does nothing, because a request
  # must match a route before any pipeline runs. See the README.
  pipeline :static do
    plug Amber::Pipe::Error.new
    plug Amber::Pipe::Static.new("./public")
  end

  routes :web do
    get "/", TodosController, :index
    post "/todos", TodosController, :create
    post "/todos/:id/toggle", TodosController, :toggle
    post "/todos/:id/delete", TodosController, :delete
  end

  # The catch-all that makes static files reachable. Explicit :web routes
  # above still win over this wildcard.
  routes :static do
    get "/*", Amber::Controller::Static, :index
  end
end

Amber::Server.start
