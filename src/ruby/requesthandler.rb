require 'RiakClientInstance'
#gem install sinatra

require 'sinatra'
require 'warden'

class BleaterApp < Sinatra::Application

get '/login' do
  haml :login
end

post '/session' do
  if authorized?
    redirect "/"
  else
    redirect "/login"
  end
end

post '/unauthenticated' do
  env['warden'].authenticate!
  if env['warden'].authenticated?
    redirect '/'
  else
    redirect '/login'
  end
end

get '/logout' do 
  env['warden'].logout
  redirect '/login'
end

get '/api/timeline/:userid' do
    processTimeline params[:userid]
end

get '/api/tweets/:userid' do
    retrieveTweets params[:userid]
end

post '/api/tweet' do
  authenticated?
  postTweet params[:userid] req.body
end

get '/api/profile/:userid' do
  getProfile params["userid"]
end

post '/api/follow' do
  authenticated?
  followUser request["follower"]  request["followee"]
end

post '/api/unfollow' do
  authenticated?
  unfollowUser request["unfollower"] request["unfollowee"]
end

#DON'T DO THIS
post '/api/newuser' do
  uinfo = {
    "name" : request["name"]
    "handle" : request["handle"]
    "email" : request["email"]
    "password" : request["password"]
  }
  createUser uinfo
end

post '/api/login' do
  validateLogin
end

get '/' do
  if authorized?
    myprofile = getProfile
    mytimeline = getTimeline
    haml :userpage, :locals => {"profile" => myprofile,
                                "tweets" => mytimeline}
  else
    haml :login, :layout => false
end

get '/user/:userid' do
  userprofile = getProfile
  usertweets = getTimeline
  haml :userpage, :locals => {"profile" => userprofile,
                              "tweets" => usertimeline}
end

template :layout do
  #menu
  #yield
end

use Rack::Session::Cookie

use Warden::Manager do |config|
    config.default_strategies :password
    # Route to redirect to when warden.authenticate! returns a false answer.gg
    config.failure_app = self
    config.serialize_into_session{ |id| id }
    config.serialize_from_session{ |id| id }
end


    Warden::Strategies.add(:password) do 
      def authenticate!
        user = client.validateCredentials params["email"] params["password"]
        !!user ? success!(user) : fail!(user)
      end

end
