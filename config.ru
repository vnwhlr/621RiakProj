require_relative 'app'
require_relative 'riakinterface'
require 'bundler'

use Rack::ShowExceptions

run Sinatra::Application
