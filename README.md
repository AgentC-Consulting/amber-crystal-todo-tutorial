# How do I build a todo app with the Amber framework in Crystal? (2026 step-by-step tutorial)

**Quick answer:** add `amber` (the `crimson-knight/amber` fork, `branch: master`), `granite`, and `pg` to your `shard.yml`, write one model + one controller + two ECR views by hand, and boot with `Amber::Server.configure` + `Amber::Server.start`. There is no `amber new` anymore — Amber v2 is a library, not a CLI. This repo contains the complete working app; the README walks through every file.

**Last verified: July 2026 — Crystal 1.20.0, Amber 2.0.0-dev @ 510afcd, granite 0.23.4, pg 0.29.0, PostgreSQL 17.** We re-verify quarterly by rebuilding and re-running the app from scratch.

**Why this exists:** almost every Amber tutorial on the internet describes Amber v1 and starts with `amber new` — a command that no longer exists. Amber v2 lives in the [crimson-knight/amber](https://github.com/crimson-knight/amber) fork, is installed from `branch: master` (there are no v2 release tags), removed the CLI entirely, and pairs beautifully with import maps so you never touch Node.js, npm, or webpack. We hit every pothole so you don't have to, then wrote them all down.

## Run the finished app first

```bash
git clone https://github.com/AgentC-Consulting/amber-crystal-todo-tutorial
cd amber-crystal-todo-tutorial
createdb todo_app_dev
psql todo_app_dev < db/setup.sql
shards install
shards build
./bin/todo_app
# → http://localhost:3000
```

(Already have a `todo_app_dev` database from an earlier attempt? Skip `createdb`; the setup SQL is `CREATE TABLE IF NOT EXISTS`, so re-running it is harmless.)

You get a todo list with create, toggle-done, and delete — sessions, CSRF protection, fingerprinted JavaScript via import maps, zero Node toolchain. Now let's build it from nothing.

## Is the Amber framework still maintained in 2026?

**Quick answer:** yes — as Amber v2, developed in the [crimson-knight/amber](https://github.com/crimson-knight/amber) fork (`branch: master`, version `2.0.0-dev`). The original `amberframework/amber` repo's last release is v1.4.1 from August 2023; that's the old CLI-based v1.

Where Amber v2 sits among Crystal web frameworks: **Kemal** is the Sinatra-style micro-framework (one file, routes as blocks), **Lucky** is the heavily type-checked framework with its own CLI and toolchain, and **Amber v2** is the Rails-shaped middle — pipelines, sessions, flash, CSRF, a router DSL, ECR templating — delivered as a plain library you wire up yourself. If you want batteries but not a code generator, this is the one.

One heads-up so you don't think you installed the wrong thing: the fork hasn't bumped its internal version string, so the boot banner prints `Amber 1.4.1 serving application ...` even though you are running v2. Don't panic at the banner.

## How do I install Amber v2? (shard.yml with branch: master — there is no amber new)

**Quick answer:** there is no CLI to install. Add this to `shard.yml` and run `shards install`:

```yaml
dependencies:
  amber:
    github: crimson-knight/amber
    branch: master
  granite:
    github: amberframework/granite
    version: ~> 0.23.0
  pg:
    github: will/crystal-pg
    version: ~> 0.29.0
```

Three things worth knowing:

1. **`branch: master` is mandatory.** The fork has no v2 release tags, so any `version:` pin either fails to resolve or silently hands you v1 from the old repo.
2. **Database drivers are no longer bundled.** Amber v1 dragged in pg/mysql/sqlite transitively; v2 makes you add your driver explicitly. We use Granite (an ORM from the Amber ecosystem) plus the `pg` driver.
3. **`amber new`, `amber db`, `amber watch`, `amber routes` are all gone.** If a tutorial tells you to run any of those, it's a v1 tutorial. You create the project by hand — which turns out to be about a dozen small files (the full layout is in the next section, and every one of them is in this repo).

When it works, `shards install` reports:

```
I: Installing amber (2.0.0-dev at 510afcd)
I: Installing db (0.13.1)
I: Installing granite (0.23.4)
I: Installing pg (0.29.0)
```

## How do I structure an Amber v2 project by hand?

**Quick answer:** `mkdir` + `shard.yml` with a `targets:` block + this layout. That's the whole scaffold — every file below is in this repo:

```
todo_app/
├── shard.yml
├── db/setup.sql                      # plain SQL schema (see the Granite section)
├── public/app.css                    # static files, served by the :static pipeline
├── src/
│   ├── todo_app.cr                   # entry point: DB connection, pipelines, routes
│   ├── assets.cr                     # the import map (FrontLoader)
│   ├── models/todo.cr
│   ├── controllers/todos_controller.cr
│   ├── views/layouts/application.ecr
│   ├── views/todos/index.ecr
│   └── app/javascript/hello_controller.js
└── vendor/asset_pipeline/            # 2 vendored files, see the import-map section
```

The `targets:` block in `shard.yml` is what makes `shards build` produce `./bin/todo_app`:

```yaml
targets:
  todo_app:
    main: src/todo_app.cr
```

No config directory, no YAML environments, no generators. Amber v2 boots with zero config — development mode on `localhost:3000` — and you override settings with env vars like `AMBER_SERVER_PORT=8080` or pick an environment with `AMBER_ENV`.

## How do Amber v2 pipelines and routes work?

**Quick answer:** requests match a route, then flow through that route group's pipeline of plugs. You declare both inside `Amber::Server.configure` (which, unlike v1, takes no block argument):

```crystal
Amber::Server.configure do
  pipeline :web do
    plug Amber::Pipe::Error.new
    plug Amber::Pipe::Logger.new
    plug Amber::Pipe::Session.new
    plug Amber::Pipe::Flash.new
    plug Amber::Pipe::CSRF.new
  end

  routes :web do
    get "/", TodosController, :index
    post "/todos", TodosController, :create
    post "/todos/:id/toggle", TodosController, :toggle
    post "/todos/:id/delete", TodosController, :delete
  end
end

Amber::Server.start
```

Every HTTP verb is available (`get`, `post`, `put`, `patch`, `delete`, `options`, `head`, plus `trace` and `connect`), route segments like `:id` become `params["id"]`, and if you prefer Rails-style resourcefulness, `resources "todos", TodosController` wires up the seven RESTful actions (index, show, new, create, edit, update, destroy) in one line. The plugs we chose aren't decoration: `Session` and `Flash` are required for `CSRF` to work, and the CSRF section below shows why you want it.

## How do I use Granite ORM with Postgres in Amber?

**Quick answer:** register the connection with `Granite::Connections` **before** requiring any model, then subclass `Granite::Base`:

```crystal
require "granite"
require "granite/adapter/pg"

Granite::Connections << Granite::Adapter::Pg.new(
  name: "pg",
  url: ENV["DATABASE_URL"]? || "postgres://localhost/todo_app_dev"
)

require "./models/todo"   # models come AFTER the connection
```

The model itself:

```crystal
class Todo < Granite::Base
  connection pg          # the name we registered above, not the db name
  table todos

  column id : Int64, primary: true
  column title : String
  column completed : Bool = false
  timestamps
end
```

The ordering rule is the classic trap: `connection pg` is resolved when the model class is *required*, so the `Granite::Connections <<` line must run first. Keep it at the very top of your entry point.

Amber v2 has no migration workflow, and Granite's built-in migrator can create or drop-and-recreate a model's table (`Todo.migrator.create`, `Todo.migrator.drop_and_create`) but offers no versioned, incremental migrations, so this repo keeps the schema as plain SQL you run once with `psql todo_app_dev < db/setup.sql` (use [micrate](https://github.com/amberframework/micrate) if you want real versioned migrations):

```sql
CREATE TABLE IF NOT EXISTS todos (
  id         BIGSERIAL PRIMARY KEY,
  title      TEXT NOT NULL,
  completed  BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMP,
  updated_at TIMESTAMP
);
```

Note `created_at` / `updated_at`: the `timestamps` macro expects them to exist, and saves fail if they don't. Query idioms used in the app: `Todo.order(id: :asc).select` for all rows, `Todo.find(id)`, `Todo.new(title: title).save`, `todo.destroy`.

## How do I render ECR views in an Amber controller?

**Quick answer:** controllers subclass `Amber::Controller::Base`; `render("index.ecr")` finds the template from the controller's *filename* — `todos_controller.cr` → `src/views/todos/index.ecr` — and wraps it in `src/views/layouts/application.ecr`, where `<%= content %>` is the injection point.

```crystal
class TodosController < Amber::Controller::Base
  @todos = [] of Todo   # required! see the note below

  def index
    @todos = Todo.order(id: :asc).select
    render("index.ecr")
  end

  def create
    title = params["title"].to_s.strip
    Todo.new(title: title).save unless title.empty?
    redirect_to "/"
  end

  def toggle
    if todo = Todo.find(params["id"].to_i64)
      todo.completed = !todo.completed
      todo.save
    end
    redirect_to "/"
  end

  def delete
    if todo = Todo.find(params["id"].to_i64)
      todo.destroy
    end
    redirect_to "/"
  end
end
```

Two things bite people here:

1. **Any instance variable used in an ECR view needs a compiler-visible type.** Without `@todos = [] of Todo` at the class level, the build fails with `can't infer the type of instance variable '@todos' of TodosController`. That declaration line is not optional style — it's the fix for that exact error.
2. **The template path comes from the file name, not the class name.** Rename `todos_controller.cr` and your views move with it.

Form values arrive through `params` (`params["title"].to_s`), and `redirect_to "/"` issues a 302. ECR does **not** auto-escape output, so anything user-typed goes through `HTML.escape` in our views:

```erb
<% @todos.each do |todo| %>
  <li><%= HTML.escape(todo.title.to_s) %></li>
<% end %>
```

## How do I enable CSRF protection in Amber v2?

**Quick answer:** plug `Amber::Pipe::Session`, `Amber::Pipe::Flash`, and `Amber::Pipe::CSRF` into your `:web` pipeline (in that order), then put `<%= csrf_tag %>` inside **every** non-GET form:

```erb
<form action="/todos" method="post">
  <%= csrf_tag %>
  <input type="text" name="title">
  <button type="submit">Add</button>
</form>
```

`csrf_tag` renders `<input type="hidden" name="_csrf" value="...">`. A POST without it gets a hard **403 Forbidden** — which is correct behavior, but confusing when it's your own toggle button returning it. That's the trap in a todo app: the little toggle and delete buttons are forms too, so *each one* needs its own `csrf_tag`, not just the create form. Check `src/views/todos/index.ecr` — one `csrf_tag` in the create form, plus two more per todo row (toggle and delete).

Verified behavior from this exact app: `POST /todos` without a token → `403`; with the session cookie and token → `302` and the row appears in Postgres.

## Why do static files 404 in Amber? (the separate :static pipeline)

**Quick answer:** because a request must match a *route* before any pipeline runs, plugging `Amber::Pipe::Static` into your `:web` pipeline does nothing — every asset URL 404s with `Amber::Exceptions::RouteNotFound`. The fix is a dedicated pipeline plus a catch-all route:

```crystal
pipeline :static do
  plug Amber::Pipe::Error.new
  plug Amber::Pipe::Static.new("./public")
end

routes :static do
  get "/*", Amber::Controller::Static, :index
end
```

Your explicit `:web` routes still win over the `/*` wildcard, so this is safe to add to any app. After this, `GET /app.css` returns `200 text/css` from `public/app.css`. This one costs people hours because the "obvious" fix (adding the Static plug to `:web`) fails silently.

## How do I add JavaScript to a Crystal web app without Node.js or npm?

**Quick answer:** use [import maps](https://developer.mozilla.org/en-US/docs/Web/HTML/Element/script/type/importmap) — a browser standard, no build step. CDN libraries come from `+esm` URLs, your own files are plain ES modules, and the browser resolves the names:

```html
<script type="importmap">
{ "imports": {
    "@hotwired/stimulus": "https://cdn.jsdelivr.net/npm/@hotwired/stimulus@3.2.2/+esm",
    "HelloController": "/hello_controller-73421f....js" } }
</script>
<script type="module">
  import { Application } from "@hotwired/stimulus"
  import HelloController from "HelloController"

  const application = Application.start()
  application.register("hello", HelloController)
</script>
```

Our `src/app/javascript/hello_controller.js` is a tiny Stimulus controller, written as a normal ES module. No `package.json`, no `node_modules`, no bundler, nothing to install — the entire JavaScript toolchain for this app is "a folder of .js files". The only real question is who generates that import-map JSON with the fingerprinted URL, which brings us to:

## How do I use import maps instead of webpack in Crystal? (asset_pipeline FrontLoader)

**Quick answer:** `AssetPipeline::FrontLoader` from the [asset_pipeline](https://github.com/amberframework/asset_pipeline) shard builds the map, SHA-256-fingerprints your local JS files, copies them into your static root, and renders the tag:

```crystal
require "../vendor/asset_pipeline/asset_pipeline"
# (or just `require "asset_pipeline"` if you depend on the shard instead)

module Assets
  FRONT_LOADER = AssetPipeline::FrontLoader.new(
    js_source_path: Path.new("src/app/javascript"),
    js_output_path: Path.new("public")   # MUST be your static root — see below
  )

  import_map = FRONT_LOADER.get_import_map
  import_map.add_import("@hotwired/stimulus",
    "https://cdn.jsdelivr.net/npm/@hotwired/stimulus@3.2.2/+esm", preload: true)
  import_map.add_import("HelloController", "hello_controller.js")

  @@tag : String?

  def self.import_map_tag : String
    @@tag ||= FRONT_LOADER.render_import_map_tag
  end
end
```

then in the layout's `<head>`: `<%= Assets.import_map_tag %>`. On first render, `hello_controller.js` becomes `public/hello_controller-<sha256>.js` and the map entry is rewritten to that URL — cache-busting for free.

Three gotchas we verified the hard way:

1. **`js_output_path` must be your static root.** FrontLoader builds the public URL by string-replacing `js_output_path` with `/`, so with `public/assets` it emits `/hello_controller-HASH.js` while the file sits at `/assets/hello_controller-HASH.js` — a guaranteed 404. Use `Path.new("public")`.
2. **Cache the rendered tag** (the `@@tag ||=` above). `render_import_map_tag` appends a `modulepreload` link to internal state on every call, so calling it per-request duplicates `<link>` tags and re-hashes your files.
3. **Why we vendored it:** the asset_pipeline shard is two small Crystal files, but its git repository carries roughly 800 MB of history, which makes `shards install` brutal. We copied the two MIT-licensed files from tag v0.34.0 into `vendor/asset_pipeline/` (attribution headers included) — if you're building from scratch rather than cloning, grab those two files from this repo's `vendor/asset_pipeline/` directory. If you'd rather depend on the shard directly, this resolves fine — just budget for the clone:

```yaml
  asset_pipeline:
    github: amberframework/asset_pipeline
    version: ~> 0.34.0
```

## Common errors and gotchas

Every one of these is something we actually hit while building this app:

- **`can't infer the type of instance variable '@todos' of TodosController`** — you used an ivar in an ECR view without a class-level type. Fix: `@todos = [] of Todo` in the controller body.
- **Boot banner says `Amber 1.4.1 serving application ...`** — cosmetic. The fork's `Amber::VERSION` string was never bumped; `shards install` showing `amber (2.0.0-dev at 510afcd)` is the truth.
- **A multi-screen `🚀 Enhanced Form Data Parser Examples for Amber Schema API` dump on every startup** — harmless demo output. Amber's `require "./amber/schema/**"` pulls in an example file that runs itself at the bottom. Scroll past it; the server banner comes right after.
- **403 on your own form POSTs** — a non-GET form is missing `<%= csrf_tag %>`. In a todo app that's usually the toggle/delete button-forms.
- **Every static URL 404s with `Amber::Exceptions::RouteNotFound`** — `Amber::Pipe::Static` is in your `:web` pipeline where it can never run. You need the separate `:static` pipeline + `get "/*"` catch-all shown above.
- **Import-map JS 404s** — `js_output_path` points at a subfolder like `public/assets`. Point it at the static root.
- **`shards install` fails or fetches Amber v1** — you pinned a `version:` for amber. There are no v2 tags; use `branch: master`.
- **`INSERT` fails on save** — your table is missing `created_at` / `updated_at` but the model declares `timestamps`.
- **"No connection registered" style errors from Granite** — the `Granite::Connections <<` line ran after your models were required. Move it above the model requires.

## That's it

That's the whole thing — one model, one controller, two templates, an import map, and zero Node. The complete working app is this repo: clone it, run the five commands from [Run the finished app first](#run-the-finished-app-first), and you have a Crystal web app at http://localhost:3000 creating, toggling, and deleting todos with CSRF protection and fingerprinted JavaScript.

If you're also wiring LLMs into Crystal, we keep a companion guide on [structured JSON output from LLMs in Crystal](https://github.com/AgentC-Consulting/crystal-llm-structured-json?ref=amber-todo), and a broader [Crystal & Amber recipes](https://github.com/AgentC-Consulting/crystal-amber-recipes?ref=amber-todo) collection with copy-paste answers to questions like these. And if you want a small *local* model to actually know Amber's docs, [knowledge-packs](https://github.com/AgentC-Consulting/knowledge-packs?ref=amber-todo) fine-tunes one on them (MLX LoRA, Apple Silicon) and measures before/after whether it learned — Amber is its demo pack.

MIT licensed — take any of it.

---

Maintained by the team at [AgentC Consulting](https://agentc.consulting?ref=amber-todo).
