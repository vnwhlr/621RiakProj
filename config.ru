require_relative 'app'
require_relative 'riakinterface'

use Rack::ShowExceptions

run Sinatra::Application
