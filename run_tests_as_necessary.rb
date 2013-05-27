require 'beaneater'
require 'json'
require 'daemons'

Daemons.run_proc('run_tests.rb') do
  beanstalk = Beaneater::Pool.new('127.0.0.1:11300')
  beanstalk.jobs.register('student-checklist-tests-to-run') do |job|
    job_params = JSON.parse(job.body)
    puts "job is #{job_params.inspect}"
  end
  beanstalk.jobs.process!
  beanstalk.close
end
