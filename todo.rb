require "sinatra"
require "sinatra/reloader"
require "sinatra/content_for"
require "tilt/erubis"

configure do
  enable :sessions
  set :session_secret, 'secret'
end

before do
  session[:lists] ||= []
end

helpers do
  def list_complete?(list)
    todos = list[:todos]
    !todos.empty? && todos.all? { |todo| todo[:completed] == true }
  end

  def list_class(list)
    "complete" if list_complete?(list)
  end

  def remaining_todos_count(list)
    list[:todos].select { |todo| todo[:completed] == false }.count
  end

  def sorting_lists(lists, &block)
    completed_list, incompleted_list = lists.partition { |list| list_complete?(list) }

    incompleted_list.each { |list| yield list, lists.index(list) }
    completed_list.each { |list| yield list, lists.index(list) }
  end

  def sorting_todos(todos, &block)
    completed_todo, incompleted_todo = todos.partition { |todo| todo[:completed] }

    incompleted_todo.each { |todo| yield todo, todos.index(todo) }
    completed_todo.each { |todo| yield todo, todos.index(todo) }
  end
end

get '/' do
  redirect '/lists'
end

get "/lists" do
  @lists = session[:lists]
  erb :lists, layout: :layout
end

get "/lists/new" do
  erb :new_list, layout: :layout
end

get "/lists/:list_id" do
  @list_id = params[:list_id].to_i
  @list = session[:lists][@list_id]

  erb :list, layout: :layout
end

get "/lists/:list_id/edit" do
  @list_id = params[:list_id].to_i
  @list = session[:lists][@list_id]

  erb :edit_list, layout: :layout
end

def error_message_for_list(name)
  if session[:lists].any? { |list| list[:name] == name }
    "The list name must be unique."
  elsif !(1..100).cover? name.size
    "The list name must be between 1 to 100."
  end
end

def error_message_for_todo(name)
  if !(1..100).cover? name.size
    "The list name must be between 1 to 100."
  end
end

post "/lists" do
  list_name = params[:list_name].strip

  error = error_message_for_list(list_name)
  if error
    session[:error] = error
    erb :new_list, layout: :layout
  else
    session[:lists] << { name: list_name, todos: []}
    session[:success] = "The list has been created."
    redirect "/lists"
  end
end

post "/lists/:list_id/edit" do
  list_name = params[:list_name].strip
  error = error_message_for_list(list_name)

  @list_id = params[:list_id].to_i
  @list = session[:lists][@list_id]

  if error
    session[:error] = error
    erb :edit_list, layout: :layout
  else
    @list[:name] = list_name
    session[:success] = "The list has updated successfully."
    redirect "/lists/#{list_id}"
  end
end

def next_todo_id(todos)
  max = todos.map { |todo| todo[:id] }.map || 0
  max + 1
end

post "/lists/:list_id/todos" do
  @list_id = params[:list_id].to_i
  @list = session[:lists][@list_id]

  error = error_message_for_todo(params[:todo].strip)
  if error
    session[:error] = error
    erb :list, layout: :layout
  else
    id = next_todo_id(@list[:todos])
    @list[:todos] << { id: id, name: params[:todo], completed: false }
    session[:success] = "The todo was added."
    redirect "/lists/#{@list_id}"
  end
end

post "/lists/:list_id/destroy" do
  @list_id = params[:list_id].to_i
  session[:lists].delete_at(@list_id)
  session[:delete] = "The list has been deleted." 

  redirect '/lists'
end

post "/lists/:list_id/todos/:todo_id/destroy" do
  @list_id = params[:list_id].to_i
  @list = session[:lists][@list_id]

  todo_id = params[:todo_id].to_i
  @list[:todos].delete_at(todo_id)
  session[:delete] = "The todo has been deleted"

  redirect "/lists/#{@list_id}"
end

post '/lists/:list_id/todos/:todo_id/check' do
  @list_id = params[:list_id].to_i
  @list = session[:lists][@list_id]

  todo_id = params[:todo_id].to_i
  is_completed = params[:completed] == "true"

  @list[:todos][todo_id][:completed] = is_completed
  session[:success] = "The todo has been updated."

  redirect "/lists/#{@list_id}"
end

post '/lists/:list_id/todos/complete_all' do
  @list_id = params[:list_id].to_i
  @list = session[:lists][@list_id]

  @list[:todos].each { |todo| todo[:completed] = true }
  session[:success] = "All todos have been completed."

  redirect "/lists/#{@list_id}"
end