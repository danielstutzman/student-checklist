#!/bin/bash -x
INITIALS=$1
EXERCISE_NUM=$2

unset BUNDLE_BIN_PATH
unset BUNDLE_GEMFILE
unset RBENV_HOOK_PATH
unset RBENV_ROOT
unset _ORIGINAL_GEM_PATH
unset GEMPATH
unset RUBYOPT
unset GEM_HOME
unset RBENV_VERSION

export PATH="/home/deployer/.rbenv/bin:$PATH"
eval "$(rbenv init -)"

cd /home/deployer/automated-tests/$INITIALS/$EXERCISE_NUM

if [ -e run_tests.rb ]; then
  rbenv global 1.9.3-p194
  rbenv rehash
  timeout -k 10 5 /home/deployer/.rbenv/versions/1.9.3-p194/bin/bundle exec ruby run_tests.rb
  if [ "$?" == "0" ]; then
    timeout -k 10 5 curl -d "initials=$INITIALS&task_id=G$EXERCISE_NUM" -v "http://localhost:3003/mark_task_complete"
  fi
fi
