require 'rubygems'
require 'bundler'

Bundler.require

require './web-app'

run Sinatra::Application
