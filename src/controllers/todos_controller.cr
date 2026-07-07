# All four actions for the todo list live in this one controller.
#
# Amber controllers subclass Amber::Controller::Base. Each public method
# is an action you point a route at in src/todo_app.cr.
class TodosController < Amber::Controller::Base
  # Any instance variable used inside an ECR view needs an explicit
  # type the compiler can see. Without this line the build fails with:
  #   "can't infer the type of instance variable '@todos' of TodosController"
  @todos = [] of Todo

  # GET /
  def index
    @todos = Todo.order(id: :asc).select
    # render resolves the template from this controller's FILENAME:
    # todos_controller.cr -> src/views/todos/index.ecr,
    # wrapped in src/views/layouts/application.ecr.
    render("index.ecr")
  end

  # POST /todos
  def create
    title = params["title"].to_s.strip
    Todo.new(title: title).save unless title.empty?
    redirect_to "/"
  end

  # POST /todos/:id/toggle
  def toggle
    if todo = Todo.find(params["id"].to_i64)
      todo.completed = !todo.completed
      todo.save
    end
    redirect_to "/"
  end

  # POST /todos/:id/delete
  def delete
    if todo = Todo.find(params["id"].to_i64)
      todo.destroy
    end
    redirect_to "/"
  end
end
