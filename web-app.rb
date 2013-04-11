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

Treetop.load(File.expand_path(File.join(File.dirname(__FILE__),
  'workflowy_parser.treetop')))

config_path = File.join(File.dirname(__FILE__), 'config.yaml')
CONFIG = YAML.load_file(config_path)
env = ENV['RACK_ENV'] || 'development'
if env == 'development'
  db_params = CONFIG['DATABASE_PARAMS'][env]
  ActiveRecord::Base.establish_connection(db_params)
else
  # load it in unicorn.rb
end
ActiveRecord::Base.logger = Logger.new(STDOUT)
ActiveRecord::Base.logger.formatter = proc { |sev, time, prog, msg| "#{msg}\n" }

class User < ActiveRecord::Base
  has_many :attempts
end

class Attempt < ActiveRecord::Base
  attr :student_initials, true
  belongs_to :user
end

class Outline < ActiveRecord::Base
end

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

def read_content_and_task_ids(outline)
  parser = WorkflowyParser.new
  tree = parser.parse(outline.text)
  if tree.nil?
    raise Exception, "Parse error at offset: #{@@parser.index}"
  end

  task_ids = []
  content = tree.lines.map { |triple|
    depth, optional_task_id, line, additional = triple
    if (additional || '') != ''
      line += " <a class='show-more' href='#'>(show)</a><div class='more'>" +
        additional.split("\n").join("<br>\n") + "</div>"
    end
    if optional_task_id != ''
      optional_task_id = (optional_task_id[1...4]).to_i
      task_ids.push optional_task_id
    end

    line = line.gsub(/`([^`]+)`/, "<code>\\1</code>")
    line = line.gsub(/(https?:\/\/[^ ,]+)/, "<a target='second' href='\\1'>\\1</a>")
    line = "<div id='task-#{optional_task_id}' class='margin-tasks'></div><div class='desc bullet-#{depth}'><div id='task-#{optional_task_id}' class='inline-task'></div>#{line}</div>\n"
  }.join("\n")

  # if no ID, remove
  content.gsub!(/<div id='task-' class='margin-tasks'><\/div>/, '')
  content.gsub!(/<div id='task-' class='inline-task'><\/div>/, '')
  [content, task_ids]
end

before do
  if ['/auth/google_oauth2/callback', '/auth/failure', '/login'].include?(request.path_info)
    pass
  elsif !authenticated?
    redirect '/login'
  end
end

def init_variables_for(outline, users, inline_task)
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

  @content, @all_task_ids = read_content_and_task_ids(outline)
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
  @all_initials = users.reject { |user| user.is_admin
    }.sort_by { |user| [user.first_name, user.last_name]
    }.map { |user| user.initials }

  @margin = 20 + (users.size * 26)
end

get '/' do
  outline = Outline.order('date desc').first
  redirect "/#{outline.month}/#{outline.day}"
end

get '/:month/:day' do |month, day|
  outline = Outline.where(:month => month, :day => day).first
  not_found 'No outline found for that day.' if outline.nil?
  if @current_user.is_admin
    init_variables_for(outline, User.where(:is_admin => false), false)
    haml :tasks_for_all
  else
    init_variables_for(outline, [@current_user], true)
    haml :tasks_for_one
  end
end

#get '/student' do
#  @user = User.find_by_initials('DS')
#  init_variables_for([@user], true)
#  haml :tasks_for_one
#end

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
