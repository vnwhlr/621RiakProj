require_relative 'riakinterface'
require 'sinatra'
require 'sinatra/partial'
require 'haml'

enable :dump_errors, :raise_errors
set :partial_template_engine, :haml
enable :sessions

helpers do

  def logger 
    request.logger
  end

  def userid_attr userid
    {:"data-userid" => userid}
  end

  def profileButtonTxt(bclass)
    case bclass 
      when "is-self" 
        "Self" 
      when "is-not-following" 
        "Not following" 
      when "is-following" 
        "Following" 
      else 
        "???" 
      end
  end

  def protected!
    return if authorized?
    headers['WWW-Authenticate'] = 'Basic realm="Restricted Area"'
    halt 401, "Not authorized\n"
  end

  def authorized?
    @auth ||=  Rack::Auth::Basic::Request.new(request.env)
    session['userid'] || (@auth.provided? and @auth.basic? and @auth.credentials and RiakClientInstance.new.validateCredentials(@auth.credentials[0], @auth.credentials[1]))
  end
end

get '/auth/login' do
  haml :login, :layout => false
end

post '/auth/unauthenticated' do
  redirect '/auth/login'
end

get '/auth/logout' do
  logger.debug("Logging out user #{session['userid']}.")
  session.clear
  redirect '/auth/login'
end

post '/auth/login' do
    u = BleaterAuth.validateCredentials(params["user"]["email"],params["user"]["password"])
    if(u)
    logger.debug("User #{u['uid']} successfully authenticated. Redirection to home timeline.")
      
        session['userid'] = u['uid']
        redirect '/'
    else
    logger.debug("Failed to authenticate user #{params["user"]["email"]}. Redirecting to login page")
      
        redirect '/auth/login'
    end
end

get '/api/timeline/:userid' do
    protected!
    logger.debug("Getting timeline of user #{params[:userid]}.")
    RiakClientInstance.new.retrieveTimeline params[:userid]
end

get '/api/bleats/:userid' do
   logger.debug("Getting bleats of user #{params[:userid]}.")
  
   results = RiakClientInstance.new.retrieveBleats params[:userid]
   logger.debug("Results: #{results.inspect}")
   results
end

post '/api/bleat' do
 # protected!
   logger.debug("Posting bleat from #{session['userid']}:\n#{params['content']}")
  RiakClientInstance.new.postBleat(session['userid'], params['content'])
end

get '/api/profile/:userid' do
  RiakClientInstance.new.getProfile(params["userid"])
end

post '/api/follow' do
  protected!
  logger.debug("User #{session['userid']} following #{params["followee"]}")
  RiakClientInstance.new.followUser(session['userid'], params["followee"])
end

post '/api/unfollow' do
  protected!
  logger.debug("User #{session['userid']} unfollowing #{params["unfollowee"]}")
  RiakClientInstance.new.unfollowUser(session['userid'], params["unfollowee"])
end

#DON'T DO THIS
post '/api/newuser' do
  uinfo = {
    "name" => request["name"],
    "handle" => request["handle"],
    "email" => request["email"],
    "password" => request["password"]
  }
  RiakClientInstance.new.createUser uinfo
end


get '/' do
    client = RiakClientInstance.new
    myprofile = client.fetchProfile(session['userid'], session['userid'])
    mytimeline = client.retrieveTimeline session['userid']
    haml :main, :format => :html5, :locals => {:profileinfo => myprofile,
                                :bleats => mytimeline}
  end

get '/user/:userid' do
    client = RiakClientInstance.new 
    if(!client.userExists?(params[:userid]))
	return "User not found" 
    end

      userprofile = client.fetchProfile(params[:userid], session['userid'])
      usertimeline = client.retrieveBleats params[:userid]
  haml :main, :format => :html5, :locals => {:profileinfo => userprofile,
                              :bleats => usertimeline}
end
