require 'backburner'

Backburner.configure do |config|
  config.beanstalk_url    = ['beanstalk://127.0.0.1']
  config.tube_namespace   = 'student-checklist'
  config.on_error         = lambda { |e| puts e }
  #config.max_job_retries  = 3 # default 0 retries
  #config.retry_delay      = 2 # default 5 seconds
  config.default_priority = 65536
  config.respond_timeout  = 120
  config.default_worker   = Backburner::Workers::Simple
  config.logger           = Logger.new(STDOUT)
end

class RerunTestsJob
  include Backburner::Queue
  queue_priority 10000 # most urgent priority is 0

  def self.perform(initials, exercise_nums)
    p 'here'
  end
end

Backburner.work
