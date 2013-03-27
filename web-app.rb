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

class Student < ActiveRecord::Base
  has_many :tasks, :through => :attempts
  #has_many :attempts
end

class Task < ActiveRecord::Base
  has_many :students, :through => :attempts
  #has_many :attempts
end

class Attempt < ActiveRecord::Base
  belongs_to :task
  belongs_to :student
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
  user_id && CONFIG['AUTHORIZED_GOOGLE_PLUS_UIDS'].include?(user_id)
end

before do
  if ['/auth/google_oauth2/callback', '/auth/failure', '/login'].include?(request.path_info)
    pass
  elsif !authenticated?
    redirect '/login'
  end
end

get '/' do
  tasks = Task.order('assigned_at, order_in_assigned_at')
  @tasks_by_assigned_at = {}
  tasks.each do |task|
    if @tasks_by_assigned_at[task.assigned_at].nil?
      @tasks_by_assigned_at[task.assigned_at] = []
    end
    @tasks_by_assigned_at[task.assigned_at].push task
  end

  @students = Student.all

  attempts = Attempt.all
  @attempt_by_task_id_student_id = {}
  tasks.each do |task|
    @attempt_by_task_id_student_id[task.id] = {}
  end
  attempts.each do |attempt|
    if attempt_by_student_id = @attempt_by_task_id_student_id[attempt.task_id]
      attempt_by_student_id[attempt.student_id] = attempt
    end
  end

  haml :tasks_for_all
end

get '/student' do
  @student = Student.first

  @tasks = Task.order('assigned_at, order_in_assigned_at')
  @task_id_to_attempt = {}

  @attempts = Attempt.where('student_id = ?', @student.id)
  @attempts.each do |attempt|
    @task_id_to_attempt[attempt.task_id] = attempt
  end

  haml :tasks_for_one
end

post '/student' do
  @student = Student.first
  if task_id = params['create_attempt_for_task_id']
    task = Task.find(task_id)
    attempt = Attempt.new({ :task => task, :student => @student, :completed => false })
    attempt.save!
  elsif task_id = params['abandon_attempt_for_task_id']
    attempt = Attempt.where(:student_id => @student.id, :task_id => task_id).first
    attempt.destroy if attempt
  elsif task_id = params['finish_attempt_for_task_id']
    attempt = Attempt.where(:student_id => @student.id, :task_id => task_id).first
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
  if CONFIG['AUTHORIZED_GOOGLE_PLUS_UIDS'].include?(uid)
    session[:google_plus_user_id] = uid
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

after do
  ActiveRecord::Base.clear_active_connections!
end
