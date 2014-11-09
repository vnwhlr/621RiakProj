module RiakClientInstance

require 'riak'

	def initialize 
		@client = Riak::Client.new(host: '104.131.186.243', pb_port: 10017)
	end 
#TODO: check syntax, make sure i'm using the right methods, object types matching


def processTimeline userid
  attachUserInfo = <<JSFN
function(value, keydata, arg)
{
  
  timeline = value.values[0].metadata.Links.filter(function(l){return l[0] == 'tweets';})
  return timeline.map(function(tweet) {return [tweet.timestamp.toInt, attachAuthorInformation(value, tweet)]}) 
}
JSFN


  @client.index('users', 'followed_by', userid).
    link(tag: 'timeline', keep: true).
    map(unpackTimelines, language:javascript).
    reduce('Riak.reduceSort', language: javascript)
end


def attachAuthorInformation(userid, tweets)
  begin
    userinfo = parseAuthorInfoJSON (fetchUserInfo userid)
    tweetArr = JSON.parse(tweets)
    tweetArr.map {|tweet| tweet.appendAuthorInfoJson(userinfo)}
  rescue
    #TODO: error
  end
end

def appendAuthorInfoJson(userinfo, tweet)
  tweet['userinfo'] = userinfo
end

#TODO: validate no password sibling
def validateCredentials(email, psrd)
  begin
    hashed = hashpassword psrd
    uinfoRObj = @client.bucket("userinfo").get(email)
    passwdObj = uinfoRObj.content.data
    #TODO: this is probably JSON
    return hashed.eql? passwdObj
  rescue
    #ERROR
  end
end


def getProfile(userid)
  begin
    return @client.bucket["users"][userid]
  rescue
    #TODO: error
  end
end

#TODO: validate that users exist
#TODO: validate that not already following
def followUser(followerid, followeeid)
  begin
    userBucket = @client["users"]
    if(userBucket.exists?(followee) && userBucket.exists?(follower))
      followee = userBucket[followeeid]
      followee.indexes['followedby'] << followeeid
      followee.store()
    end
  rescue
    #ERROR
  end
end

#TODO: validate that users exist
#TODO: validate that not already unfollowed
def unfollowUser(unfollowerid, unfolloweeid)
  begin
    userBucket = @client["users"]
    if(userBucket.exists?(unfollowee) && userBucket.exists?(unfollower))
      unfollowee = userBucket[unfolloweeid]
      unfollowee.indexes['followedby'].delete(unfolloweeid)
      unfollowee.store()
    end
  rescue
    #ERROR
  end
end


def createUser(uinfo)
  #TODO: generate user id. maybe goes in pre-commit hook on insertion into userinfo?
  puts @client.inspect
  userinfoBucket = @client.bucket("userinfo")
  usersBucket = @client.bucket("users")

  userIData = {
    :email => uinfo[:email],
    :password => hashpassword(uinfo[:password])
  }

  usersData = {
    :handle => uinfo[:handle],
    :name => uinfo[:name],
    :avatarurl => uinfo[:avatarurl]
  }

  userRInfoObj = initRJsonObj(userinfoBucket, uinfo[:email], "application/json",userIData)

  userRObj = initRJsonObj(usersBucket, nil, "application/json", usersData)
    #password, email goes here. MAKE HASH BROWNS OUT OF THIS PASSWORD
	userRObj.store()
  userRInfoObj.store()
  options = {:options => ['force']}
	userRObj = userRObj.reload(options).links << Riak::Link.new(useribucket, email, "user_data")
end

def initRJsonObj(bucket, key, ctype, data)
  rObj = bucket.new(key)
  rObj.content_type = ctype
  rObj.data = data
  return rObj;
end

#TODO: put this into SUPER SECRET SECURITY module 
#TODO: add SUPER SECRET SECURITY module
#TODO: DO NOT forget to add SUPER SECRET SECURITY module to .gitignore
#TODO: just kick self in the face right now because i know i'm going to forget
#TODO: done
def hashpassword pswd
  Digest::SHA1.hexdigest(pswd)
end

#TODO: make strongly consistent bucket for global info.
#TODO: probably will be a HUGE bottleneck.
#TODO: kick self in the face for using MAX_ID + 1 equivalent
#TODO: build this into the precommit hook instead of the application, ya dummy

def generateTweetID
  twid = clien["globalinfo"]["lastgeneratedtwid"]
  twid.increment_and_return
end

#TODO: validate
def fetchProfile userid
  begin
    profile = @client.bucket["users"][userid]
    return profile
  rescue
    #TODO: error
  end
end

def parseAuthorInfoJSON profile
    return JSON[{
    :name => profile.name,
    :handle => profile.handle,
    :avatarurl => profile.avatarurl
  }]
end

#TODO: change data model to mapreduce?
def retrieveTweets userid
  begin
    tlRObj = @client["timelines"][userid]
    tweetsrawJSON = JSON[tlRObj.content]
    tweets_w_author = attachAuthorInformation userid tweets
    return tweets_w_author
  rescue
    #TODO: error
  end
end

#TODO: deal with tl siblings
def postTweet(userid, tweetcontent)
  begin
    if (@client["users"].exists?(userid)) 
    tweet = {
      "timestamp" => Time::now().to_i(),
      "content" => tweetcontent
    } #create tweet object

    tweetRObj = initRJsonObj(@client["tweets"], nil, "application/json", tweet) #create a new RObject out of our tweet (we don't know the key yet)
    tweetRObj.store() #put in database, will autoassign key
    tweetRObj.reload() #get object back, now with auto-assigned key

    timelineRObj = @client["timelines"].get_or_new("#{tweet.userid}") #get timeline object or create if doesn't exist
    timelineRObj.raw_data = appendTweetToTimeline timelineJSON tweetRObj.key
    timelineRObj.store()
    else
      #TODO: invalid user
    end
  rescue
    #TODO: failure posting
  end
end

def appendTweetToTimeline(tl, tweetID)
  tidlist = JSON.parse(tl)
  tidlist += tweetID
  tlJSON['tweetids'] = JSON[tidlist]
  return tlJSON
end

end



# 
#one: get followed users using 2i. output: list of followed userids.
#two: map: keep data associated with userid. output: list of userids
#three: link: follow link for each userid to timeline
#three: foreach timeline/info value, unpack the tweetids and append the user information. output: list of tweets from all users, with attached user information, keyed on tweet id, valued on metadata + tweet id. 

#[tweet id]
#four: for each tweetid, look up the tweet id in the tweets bucket and append the tweet timestamp and content. output: list of tweets keyed on timestamp, valued on tweet content and metadata
#five: sort the tweets by timestamp through reduction.
