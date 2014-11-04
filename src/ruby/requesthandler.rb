require 'sinatra'

require 'RiakClientInstance'
#gem install sinatra

#shamelessly stolen from http://www.sinatrarb.com/faq.html#auth
helpers do
  def protected!
    return if authorized?
    headers['WWW-Authenticate'] = 'Basic realm="AuthorizationRequired"'
    halt 401, "Not authorized\n"
  end

  def authorized?
    @auth ||=  Rack::Auth::Basic::Request.new(request.env)
    @auth.provided? and @auth.basic? and @auth.credentials and validCredentials? @auth.credentials
  end

  def validCredentials? credentials
     client.validateCredentials credentials[0] credentials[1]
  end
end

get '/api/timeline/:userid' do
    processTimeline params[:userid]
end

get '/api/tweets/:userid' do
    retrieveTweets params[:userid]
end

post '/api/tweet' do
  postTweet params[:userid] req.body
end

get '/api/profile/:userid' do
  getProfile params["userid"]
end

post '/api/follow' do
  followUser request["follower"]  request["followee"]
end

post '/api/unfollow' do
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
