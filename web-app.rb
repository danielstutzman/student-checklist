require 'sinatra'
require 'json'
require 'haml'
require 'omniauth'
require 'omniauth-google-oauth2'
require 'yaml'
require 'active_record'
require 'sinatra/cometio'
require 'treetop'
require 'airbrake'
require 'beaneater'
require 'pg_search'

set :server, ['thin'] # needed to avoid eventmachine error

Treetop.load(File.expand_path(File.join(File.dirname(__FILE__),
  'workflowy_parser.treetop')))

env = ENV['RACK_ENV'] || 'development'
config_path = File.join(File.dirname(__FILE__), 'config.yaml')
if File.exists?(config_path)
  CONFIG = YAML.load_file(config_path)
  db_params = CONFIG['DATABASE_PARAMS'][env]
  ActiveRecord::Base.establish_connection(db_params)
else # for Heroku, which doesn't support creating config.yaml
  CONFIG = {}
  missing = []
  %w[GOOGLE_KEY GOOGLE_SECRET COOKIE_SIGNING_SECRET AIRBRAKE_API_KEY].each do
    |key| CONFIG[key] = ENV[key] or missing.push key
  end
  CONFIG['HOSTNAME_FOR_ONLINE_RUBY_TUTOR'] = { 'production' => ENV['HOSTNAME_FOR_ONLINE_RUBY_TUTOR'] } or missing.push 'HOSTNAME_FOR_ONLINE_RUBY_TUTOR'
  if missing.size > 0
    raise "Missing config.yaml and ENV keys #{missing.join(', ')}"
  end

  db = URI.parse(ENV['DATABASE_URL'])
  ActiveRecord::Base.establish_connection({
    :adapter  => db.scheme == 'postgres' ? 'postgresql' : db.scheme,
    :host     => db.host,
    :port     => db.port,
    :username => db.user,
    :password => db.password,
    :database => db.path[1..-1],
    :encoding => 'utf8',
  })
end

ActiveRecord::Base.logger = Logger.new(STDOUT)
ActiveRecord::Base.logger.formatter = proc { |sev, time, prog, msg| "#{msg}\n" }

if env == 'development'
  set :static_cache_control, [:public, :no_cache]
else
  Airbrake.configure { |config| config.api_key = CONFIG['AIRBRAKE_API_KEY'] }
  set :static_cache_control, [:public, :max_age => 300]
end

ONLINE_RUBY_TUTOR = CONFIG['HOSTNAME_FOR_ONLINE_RUBY_TUTOR'][env]

class User < ActiveRecord::Base
  has_many :attempts
end

class Attempt < ActiveRecord::Base
  attr :student_initials, true
  belongs_to :user
end

if env == 'development'
  class Outline < ActiveRecord::Base
    def self.search_by_text(query)
      (query != '') ? self.where("text like ?", "%#{query}%") : []
    end
  end
else
  class Outline < ActiveRecord::Base
    include PgSearch
    pg_search_scope :search_by_text, :against => :text
  end
end

class Outline < ActiveRecord::Base
  has_many :exercises
  def first_line_html
    backticks_to_html(h(self.first_line))
  end
end

class Exercise < ActiveRecord::Base
  belongs_to :outline
end

use Rack::Session::Cookie, {
  :key => 'rack.session',
  :secret => CONFIG['COOKIE_SIGNING_SECRET'],
}

use OmniAuth::Builder do
  provider :google_oauth2, CONFIG['GOOGLE_KEY'], CONFIG['GOOGLE_SECRET'], {
    :scope => 'https://www.googleapis.com/auth/plus.me',
    :access_type => 'online',
  }
end

use Airbrake::Sinatra

set :port, 4002
set :public_folder, 'public'
set :haml, { :format => :html5, :escape_html => true, :ugly => true }

def h(text)
  Rack::Utils.escape_html(text)
end
def backticks_to_html(text)
  text.gsub(/`([^`]+)`/, "<code>\\1</code>")
end

beanstalk = Beaneater::Pool.new('127.0.0.1:11300')

def authenticated?
  user_id = session[:google_plus_user_id]
  if user_id
    @current_user = User.find_by_google_plus_user_id(user_id)
  end
  @current_user != nil
end

def read_title_content_and_task_ids(outline)
  parser = WorkflowyParser.new
  tree = parser.parse(outline.text)
  if tree.nil?
    raise Exception, "Parse error at offset: #{parser.index}"
  end

  title_text = tree.title.gsub('`', '')
  title_html = backticks_to_html(h(tree.title))

  task_ids = []
  content = tree.lines.map { |triple|
    depth, task_id, line, additional = triple

    line = Rack::Utils.escape_html(line).gsub('&#x2F;', '/')
    line = line.gsub(/(https?:\/\/[^ ,]+)/, "<a target='second' href='\\1'>\\1</a>")

    if task_id != ''
      task_ids.push task_id

      if task_id[0] == 'C' # challenge exercise
        line = "<a target='second' href='http://#{ONLINE_RUBY_TUTOR}/exercise/#{task_id}'>Challenge #{task_id[1...4].to_i}:</a> #{line}"
      elsif task_id[0] == 'D' # demonstration exercise
        line = "<a target='second' href='http://#{ONLINE_RUBY_TUTOR}/exercise/#{task_id}'>Demonstration #{task_id[1...4].to_i}:</a> #{line}"
        begin
          attributes = YAML.load(additional)
          if attributes['starting_code']
            line += "\n<pre>#{attributes['starting_code']}</pre>\n"
          end
        rescue Psych::SyntaxError => e
          line += "<br><i>#{e}</i>"
        end
      elsif task_id[0] == 'G' # GitHub challenge
        line = "<a class='github-challenge' href='#'>GitHub challenge #{task_id[1...4].to_i}</a>: #{line}"
      end
    end

    line = backticks_to_html(line)

    if !%w[C D].include?(task_id[0]) && (additional || '') != ''
      line += " <a class='show-more' href='#'>(show)</a><div class='more'>" +
        additional.split("\n").join("<br>\n") + "</div>"
    end

    comment_class = (line.start_with?('#')) ? 'comment' : ''

    line = "<div id='task-#{task_id}' class='margin-tasks'></div><div class='desc bullet-#{depth} #{comment_class}'><div id='task-#{task_id}' class='inline-task'></div>#{line}</div>\n"

    # if no ID, remove
    line.gsub!(/<div id='task-' class='margin-tasks'><\/div>/, '')
    line.gsub!(/<div id='task-' class='inline-task'><\/div>/, '')
    line
  }.join("\n")

  [title_text, title_html, content, task_ids]
end

before do
  if %w[
    /auth/google_oauth2/callback
    /auth/failure
    /login
    /mark_task_complete
    /cometio/io
    /github_post_receive_web_hook
    /ping
  ].include?(request.path_info)
    pass
  elsif !authenticated?
    redirect '/login'
  end
end

def init_variables_for(outline, users, view_as_admin)
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

  @title_text, @title_html, @content, @all_task_ids =
    read_title_content_and_task_ids(outline)
  if view_as_admin
    @content.gsub!(
      /<div id='task-([A-Z][0-9]+)' class='inline-task'><\/div>/, '')
  else
    @content.gsub!(
      /<div id='task-([A-Z][0-9]+)' class='margin-tasks'><\/div>/, '')
  end
  @attempts = attempts.map { |attempt|
    {
      'task_id'  => attempt.task_id,
      'initials' => attempt.user.initials,
      'status'   => attempt.status,
    }
  }
  @all_initials = users.map { |user| user.initials }

  @margin = 20 + (users.size * 28)
end

get '/' do
  @outlines =
    Outline.select('id, date, month, day, first_line').order('date desc')
  haml :outlines
end

get '/:month/:day' do |month, day|
  @outline = Outline.where(:month => month, :day => day).first
  not_found 'No outline found for that day.' if @outline.nil?
  if @current_user.is_admin && params['as_student'] != 'true'
    students = User.where(:is_student => true).order('seating_order, id')
    init_variables_for(@outline, students, true)
    haml :tasks_for_all
  else
    init_variables_for(@outline, [@current_user], false)
    haml :tasks_for_one
  end
end

get '/:month/:day/edit' do |month, day|
  if !@current_user.is_admin
    redirect '/auth/failure?message=You+must+be+an+admin+to+edit+pages'
  end
  @outline = Outline.where(:month => month, :day => day).first || Outline.new
  haml :edit_page
end

post '/:month/:day/edit' do |month, day|
  if !@current_user.is_admin
    redirect '/auth/failure?message=You+must+be+an+admin+to+edit+pages'
  end
  unless %w[jan feb mar apr may jun jul aug sep oct nov dec].include?(month)
    halt "Bad month"
  end
  halt "Bad day, should be 2 characters" if day.size != 2

  text = params['text'].gsub("\r\n", "\n")
  parser = WorkflowyParser.new
  tree = parser.parse(text)
  if tree.nil?
    raise Exception, "Parse error at offset: #{parser.index}"
  end

  @outline = Outline.where(:month => month, :day => day).first

  all_task_ids = {}
  tree.lines.each do |triple|
    depth, task_id, line, additional = triple
    next if task_id == ''

    if all_task_ids[task_id]
      raise "Task_id #{task_id} mentioned twice in page"
    else
      all_task_ids[task_id] = true
    end

    exercise = Exercise.find_by_task_id(task_id) ||
               Exercise.new(:task_id => task_id)
    if exercise.outline_id && @outline && exercise.outline_id != @outline.id
      raise "Task #{task_id} already belongs to outline #{exercise.outline_id}"
    end

    if %w[C D].include?(task_id[0]) # challenge or demonstration
      description_yaml = YAML.dump({ 'description' => line })
      YAML.load(additional) # make sure it parses
      exercise.yaml = description_yaml + "\n" + additional
    end
    exercise.save!
  end

  if @outline.nil?
    @outline = Outline.new({
      :month => month,
      :day   => day,
      :year  => '2013',
      :date  => "2013-#{month}-#{day}",
    })
  end
  @outline.text = text
  @outline.first_line = text.split("\n").first
  @outline.save!

  tree.lines.each do |triple|
    depth, task_id, line, additional = triple
    next if task_id == ''
    exercise = Exercise.find_by_task_id(task_id)
    exercise.outline_id = @outline.id
    exercise.save!
  end

  redirect "/#{month}/#{day}"
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

post '/mark_task_complete' do
  task_id = params['task_id']

  if params['google_plus_user_id']
    user = User.find_by_google_plus_user_id(params['google_plus_user_id'])
  elsif params['initials']
    user = User.find_by_initials(params['initials'])
  end

  if user
    attempt = Attempt.where(:task_id => task_id, :user_id => user.id).first ||
              Attempt.new(:task_id => task_id, :user_id => user.id)
    if attempt
      attempt.status = 'complete'
      attempt.save!
      attempt_id = "task-#{attempt.task_id}-#{user.initials}"
      CometIO.push :update_attempt,
        :attempt_id => attempt_id,
        :new_status => attempt.status
      'OK'
    end
  end
end

get '/students' do
  @students = User.where(:is_student => true).order('id')
  haml :students
end

get '/users' do
  if !@current_user.is_admin
    redirect '/auth/failure?message=You+must+be+an+admin+to+edit+users'
  end
  @users = User.order('seating_order, id')
  haml :users
end

post '/users' do
  if !@current_user.is_admin
    redirect '/auth/failure?message=You+must+be+an+admin+to+edit+users'
  end

  fields = %w[id first_name last_name initials google_plus_user_id is_admin
    is_student email seating_order github_username]

  User.transaction do
    User.order('id').each do |user|
      fields.each do |field|
        value = params["#{field}_#{user.id}"]
        value = nil if value == ''
        user[field] = value
      end
      user.save!
    end

    if (params["first_name_"] || '') != ''
      user = User.new
      fields.each do |field|
        value = params["#{field}_"]
        value = nil if value == ''
        user[field] = value
      end
      user.save!
    end
  end

  redirect '/users'
end

post '/github_post_receive_web_hook' do
  initials_to_exercise_nums = {}
  json = JSON.load(params['payload'])
  json['commits'].each do |commit|
    author = User.find_by_github_username(commit['author']['username'])
    if author
      paths = commit['added'] + commit['modified'] + commit['removed']
      exercise_nums = paths.map { |path| path.split("/")[0] }
      exercise_nums.reject! { |num| num.to_i.to_s != num } # only numeric
      exercise_nums.each do |exercise_num|
        if initials_to_exercise_nums[author.initials].nil?
          initials_to_exercise_nums[author.initials] = {}
        end
        initials_to_exercise_nums[author.initials][exercise_num] = true
      end
    end
  end

  tube = beanstalk.tubes['student-checklist-tests-to-run']
  initials_to_exercise_nums.each do |initials, exercise_nums|
    params = {
      "initials" => initials,
      "exercise_nums" => exercise_nums.keys.sort,
    }
    tube.put JSON.dump(params), :pri => 10000
  end

  "OK\n"
end

get '/attendance' do
  @students = User.where(:is_student => true).order('id')
  @outlines = Outline.order("date")
  haml :attendance
end

get '/ping' do
  User.first
  "OK\n"
end

get '/search' do
  @outlines = Outline.search_by_text(params['query'])
  haml :search_results
end

post "/move_highlight" do
  if @current_user.is_admin
    CometIO.push :move_highlight, :num_desc => params["num_desc"].to_i
    "OK\n"
  else
    "Must be admin\n"
  end
end

after do
  ActiveRecord::Base.clear_active_connections!
end
