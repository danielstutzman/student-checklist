require 'sinatra'
require 'pry'
require 'json'
require 'haml'
require 'omniauth'
require 'omniauth-google-oauth2'
require 'yaml'
require 'active_record'
require 'sinatra/cometio'
require 'treetop'

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

content_string = File.read('content.txt')
Treetop.load(File.expand_path(File.join(File.dirname(__FILE__),
  'workflowy_parser.treetop')))
parser = WorkflowyParser.new
tree = parser.parse(content_string)
if tree.nil?
  raise Exception, "Parse error at offset: #{@@parser.index}"
end
$content_lines = tree.lines
tree = nil

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

def read_content_and_task_ids
  content = $content_lines.map { |triple|
    depth, line, additional = triple
    if additional
      line += '<br>' + additional.split("\n").join("<br>\n")
    end

    line = line.gsub(/`([^`]+)`/, "<code>\\1</code>")
    line = line.gsub(/(https?:\/\/[^ ,]+)/, "<a target='second' href='\\1'>\\1</a>")
    line = "<div class='margin-tasks'></div><div class='desc bullet-#{depth}'><div class='inline-task'></div>#{line}</div>\n"
  }.join("\n")
  task_ids = []
  content = content.gsub(
      /<div class='margin-tasks'><\/div><div class='([^']*)'><div class='inline-task'><\/div>(.*)([UI])([0-9]{3}) ?(.*)$/) do
    task_id = $4.to_i
    raise "Duplicate task_id #{task_id}" if task_ids.include?(task_id)
    task_ids.push task_id
    "<div id='task-#{task_id}' class='margin-tasks'></div><div class='#{$1}'><div id='task-#{task_id}' class='inline-task'></div>#{$2}#{$5}"
  end
  content.gsub!(/<div class='margin-tasks'><\/div>/, '') # if no ID, remove
  content.gsub!(/<div class='inline-task'><\/div>/, '') # if no ID, remove
  [content, task_ids]
end

before do
  if ['/auth/google_oauth2/callback', '/auth/failure', '/login'].include?(request.path_info)
    pass
  elsif !authenticated?
    redirect '/login'
  end
end

def init_variables_for(users, inline_task)
  @users = users
  user_id_to_initials = {}
  @users.each do |user|
    user_id_to_initials[user.id] = user.initials
  end

  attempts = Attempt.where(:user_id => users.map { |user| user.id })
  @attempt_by_task_id_user_id = {}
  attempts.each do |attempt|
    if @attempt_by_task_id_user_id[attempt.task_id].nil?
      @attempt_by_task_id_user_id[attempt.task_id] = {}
    end
    @attempt_by_task_id_user_id[attempt.task_id][attempt.user_id] = attempt
  end

  @content, @all_task_ids = read_content_and_task_ids
  if inline_task
    @content.gsub!(/<div id='task-([0-9]+)' class='margin-tasks'><\/div>/, '')
  else
    @content.gsub!(/<div id='task-([0-9]+)' class='inline-task'><\/div>/, '')
  end
  @attempts = attempts.map { |attempt|
    {
      'task_id'  => attempt.task_id,
      'initials' => attempt.user.initials,
      'status'   => attempt.status,
    }
  }
  @all_initials = users.map { |user| user.initials }

  @margin = 20 + (users.size * 26)
end

get '/' do
  init_variables_for(User.all, false)
  haml :tasks_for_all
end

get '/student' do
  @user = User.first
  init_variables_for([@user], true)
  haml :tasks_for_one
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
  CometIO.push :refresh_all, {}
  'OK'
end

post '/update_attempt' do
  _, task_id, initials = params['attempt_id'].split('-')
  user = User.where(:initials => initials).first or raise "Can't find initials"
  attempt = Attempt.where(:task_id => task_id, :user_id => user.id).first ||
            Attempt.new(:task_id => task_id, :user_id => user.id)
  attempt.status = params['new_status']
  attempt.save!
  CometIO.push :update_attempt,
    :attempt_id => params['attempt_id'],
    :new_status => params['new_status']
  'OK'
end

post '/logout' do
  session[:google_plus_user_id] = nil
  redirect '/'
end

after do
  ActiveRecord::Base.clear_active_connections!
end
