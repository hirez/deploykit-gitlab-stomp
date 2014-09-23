require 'rubygems'
require 'bundler'

Bundler.require

require 'sinatra'

set :env,  :production
disable :run

require './gitlab-stomp.rb'

run Sinatra::Application
