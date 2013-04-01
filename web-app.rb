require 'sinatra'
require 'pry'
require 'json'
require 'haml'
require 'omniauth'
require 'omniauth-google-oauth2'
require 'yaml'
require 'active_record'
require 'sinatra/cometio'

set :server, ['thin'] # needed to avoid eventmachine error

database_params = {
  :adapter   => 'sqlite3',
  :database  => 'database.sqlite3',
}
#database_params = {
#  :host     => "localhost",
#  :adapter  => "postgresql",
#  :username => "postgres",
#  :password => "postgres",
#  :database => "postgres",
#  :encoding => "unicode",
#}

ActiveRecord::Base.establish_connection(database_params)
ActiveRecord::Base.logger = Logger.new(STDOUT)
ActiveRecord::Base.logger.formatter = proc { |sev, time, prog, msg| "#{msg}\n" }

class User < ActiveRecord::Base
  has_many :attempts
end

class Attempt < ActiveRecord::Base
  attr :student_initials, true
  belongs_to :user
end

config_path = File.join(File.dirname(__FILE__), 'config.yaml')
CONFIG = YAML.load_file(config_path)

use Rack::Session::Cookie, {
  :key => 'rack.session',
  :secret => CONFIG['COOKIE_SIGNING_SECRET'],
}

set :port, 4567
set :public_folder, 'public'
set :static_cache_control, [:public, :no_cache]
set :haml, { :format => :html5, :escape_html => true, :ugly => true }

def authenticated?
  user_id = session[:google_plus_user_id]
  if user_id
    @current_user = User.find_by_google_plus_user_id(user_id)
  end
  @current_user != nil
end

def read_content
  content = File.read('content.txt')
  content = content.split("\n").map { |line|
    #line = line.gsub(/^- /, '&nbsp;&nbsp;&nbsp;&#9679;&nbsp;&nbsp;')
    #line = line.gsub(/^  - /,
    #  '&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&#9675;&nbsp;&nbsp;')
    line = "<div class='task'></div><div class='desc'>#{line}</div>\n"
    line = line.gsub(/'desc'>((  )*)([-#]) /) {
      depth = $1.length / 2
      if $3 == '#'
        "'desc heading'>"
      elsif $3 == '-'
        "'desc bullet-#{depth}'>"
      else
        "'desc'>"
      end
    }
  }.join("\n")
  content = content.gsub(/^<div class='task'><\/div>(.*)(I)(001) ?(.*)$/) {
    task_id = $3.to_i
    "<div id='task-#{task_id}' class='task'>#{$2}#{$3}</div>#{$1}#{$4}"
  }
  content
end

before do
  if ['/auth/google_oauth2/callback', '/auth/failure', '/login'].include?(request.path_info)
    pass
  elsif !authenticated?
    redirect '/login'
  end
end

get '/' do
  @users = User.all
  user_id_to_initials = {}
  @users.each do |user|
    user_id_to_initials[user.id] = user.initials
  end

  attempts = Attempt.all
  @attempt_by_task_id_user_id = {}
  attempts.each do |attempt|
    if @attempt_by_task_id_user_id[attempt.task_id].nil?
      @attempt_by_task_id_user_id[attempt.task_id] = {}
    end
    @attempt_by_task_id_user_id[attempt.task_id][attempt.user_id] = attempt
  end

  @content = read_content
  @attempts_json = attempts.map { |attempt|
    {
      'task_id'   => attempt.task_id,
      'initials'  => attempt.user.initials,
      'completed' => attempt.completed,
    }
  }.to_json
  @all_initials_json = User.all.map { |user| user.initials }.to_json

  haml :tasks_for_all
end

get '/student' do
  @user = User.first
  @content = read_content

  haml :tasks_for_one
end

post '/student' do
  @user = User.first
  if task_id = params['create_attempt_for_task_id']
    task = Task.find(task_id)
    attempt = Attempt.new({ :task => task, :user => @user, :completed => false })
    attempt.save!
  elsif task_id = params['abandon_attempt_for_task_id']
    attempt = Attempt.where(:user_id => @user.id, :task_id => task_id).first
    attempt.destroy if attempt
  elsif task_id = params['finish_attempt_for_task_id']
    attempt = Attempt.where(:user_id => @user.id, :task_id => task_id).first
    attempt.completed = true
    attempt.save!
  end
  redirect '/student'
end

get '/login' do
  haml :login
end

get '/new' do
  haml :new_task
end

post '/create' do
  tasks_in_same_day = Task.where('assigned_at = ?', params['assigned_at'])
  next_order = tasks_in_same_day.map { |task| task.order_in_assigned_at }.max.to_i + 1

  task = Task.new
  task.description = params['description']
  task.assigned_at = params['assigned_at']
  task.order_in_assigned_at = next_order
  task.save!

  CometIO.push :update, :section => 'all'

  redirect '/'
end

use OmniAuth::Builder do
  provider :google_oauth2, CONFIG['GOOGLE_KEY'], CONFIG['GOOGLE_SECRET'], {
    :scope => 'https://www.googleapis.com/auth/plus.me',
    :access_type => 'online',
  }
end

# Example callback:
#
# {"provider"=>"google_oauth2",
#  "uid"=>"112826277336975923063",
#  "info"=>{},
#  "credentials"=>
#   {"token"=>"ya29.AHES6ZRDLUipo8HB5wLy7MoO81vjath9i7Wx-4nI-duhXyE",
#    "expires_at"=>1363146592,
#    "expires"=>true},
#  "extra"=>{"raw_info"=>{"id"=>"112826277336975923063"}}}
#
get '/auth/google_oauth2/callback' do
  response = request.env['omniauth.auth']
  uid = response['uid']
  session[:google_plus_user_id] = uid
  if authenticated?
    redirect "/"
  else
    redirect "/auth/failure?message=Sorry,+you're+not+on+the+list.+Contact+dtstutz@gmail.com+to+be+added."
  end
end

get '/auth/failure' do
  @auth_failure_message = params['message']
  haml :login
end

get '/refresh_all' do
  CometIO.push :update, :section => 'all'
end

post '/delete_task' do
  task_id = params['task_id']
  task = Task.find_by_id(task_id)
  task.destroy if task
  redirect "/"
end

post '/logout' do
  session[:google_plus_user_id] = nil
  redirect '/'
end

after do
  ActiveRecord::Base.clear_active_connections!
end
