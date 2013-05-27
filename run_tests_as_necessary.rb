require 'beaneater'
require 'json'
require 'daemons'

options = {
  :dir_mode   => :script,
  :dir        => "tmp/pids",
  :log_dir    => "/home/deployer/student-checklist/log",
  :log_output => true,
}
Daemons.run_proc('run_tests.rb', options) do
  CurrentProcess.change_privilege "deployer"
  beanstalk = Beaneater::Pool.new('127.0.0.1:11300')
  beanstalk.jobs.register('student-checklist-tests-to-run') do |job|
    job_params = JSON.parse(job.body)
    puts "job is #{job_params.inspect}"
    initials = job_params['initials']
    exercise_nums = job_params['exercise_nums']
    if initials.match(/^[A-Z][A-Z]$/)
      puts `cd /home/deployer/automated-tests/#{initials}; git pull`
      puts "cd /home/deployer/automated-tests/#{initials}; git pull"
      exercise_nums.each do |exercise_num|
        if exercise_num.match(/^[0-9]+/)
          puts "bash -lc \"/home/deployer/student-checklist/run_test.sh #{initials} #{exercise_num}\""
          puts `bash -lc "/home/deployer/student-checklist/run_test.sh #{initials} #{exercise_num}"`
        else
          puts "Bad exercise_num #{exercise_num}"
        end
      end
    else
      puts "Bad initials #{initials}"
    end
  end
  beanstalk.jobs.process!
  beanstalk.close
end
