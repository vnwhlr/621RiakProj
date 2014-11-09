class RiakClientInstance

require 'riak'
require 'bcrypt' 

@@new_id_range = 100

  attr_accessor :selfid
  attr_accessor :client

  def initialize 
    @client = Riak::Client.new(host: '104.131.186.243', pb_port: 10017)
  end 

  def retrieveTimeline(userid)
  retrieveUserInfo = <<JSFN1
  function(userinforval, keydata, args){
    var userinfo = Riak.mapValues(userinforval)[0];
    var userid = userinforval.key;
    return[['timelines', userid, {'uid' : userid, 'userinfo' : userinfo}]];
  }
JSFN1
    
  unpackTimeline = <<JSFN2
  function(timelinerval, userinfo, args){
    var timeline = Riak.mapValuesJson(timelinerval)[0]['tweet_ids'];
    return timeline.map(function(tweetid){
      return ['tweets', tweetid, userinfo]
    })
 }
JSFN2

  attachTweetInfo = <<JSFN3
  function(tweetrval, userinfo, args){
    var tweet = Riak.mapValuesJson(tweetrval)[0];
    return [{
      'tid' : tweetrval.key,
      'timestamp' : tweet.timestamp,
      'body' : tweet.content,
      'userinfo' : userinfo
    }];
  }
JSFN3

  sortDescTimestamp = <<JSFN4
  function(t1, t2)
  {
    return t2.timestamp - t1.timestamp;
  }
JSFN4

    begin
    results = Riak::MapReduce.new(@client).index('users', 'followed_by_int', userid.to_i)
    .map(retrieveUserInfo, {:language => 'javascript'})
    .map(unpackTimeline, {:language => 'javascript'})
    .map(attachTweetInfo, {:language => 'javascript'})
    .reduce('Riak.reduceSort', {:arg => sortDescTimestamp, :language => 'javascript', :keep => true}).run
resultsf = []

    results.each do |tw|
         uinfo = JSON[tw['userinfo']['userinfo']]
         oinfo = {'uid' => tw['userinfo']['uid'], 'tid' => tw['tid'], 'body' => tw['body'], 'timestamp' => tw['timestamp']}
      resultsf.push(oinfo.merge(uinfo))
    end
  return resultsf
      

    rescue => exception
      puts $!
      puts exception.backtrace
    end
  end


#TODO: validate no password sibling



#TODO: validate that users exist
#TODO: validate that not already following
def followUser(followerid, followeeid)
  begin
      userBucket = @client["users"]
      if(userBucket.exists?(followeeid) && userBucket.exists?(followerid))
        followee = userBucket[followeeid]
        @client["users"].counter('fc_'+followerid).increment
        followee.indexes['followed_by_int'] << followerid.to_i
        followee.store
      end
  rescue
    puts $!
    #ERROR
  end
end

#TODO: validate that users exist
#TODO: validate that not already unfollowed
def unfollowUser(unfollowerid, unfolloweeid)
  begin
      userBucket = @client["users"]
      if(userBucket.exists?(unfolloweeid) && userBucket.exists?(unfollowerid))
        @client["users"].counter('fc_'+unfollowerid).decrement
        unfollowee = userBucket[unfolloweeid]
        unfollowee.indexes['followed_by_int'].delete(unfollowerid.to_i)
        unfollowee.store
      end
  rescue
    puts $!
    #ERROR
  end
end


def createUser(uinfo)
  #TODO: generate user id. maybe goes in pre-commit hook on insertion into userinfo?

  userinfoBucket = @client["userinfo"]
  usersBucket = @client["users"]
  
  uidCounter = usersBucket.counter('max_user_id') # fetch counter
  uid = uidCounter.value + Random.new.rand(@@new_id_range) #generate new uid, randomizing to avoid collisions
  uidCounter.increment(@@new_id_range) #increment

  #create value to be stored in userinfo bucket
  userIData = {
    :email => uinfo[:email],
    :password => hashpassword(uinfo[:password]).to_s,
    :uid => uid.to_s
  }
  userRInfoObj = initRObj(userinfoBucket, uinfo[:email], "application/json",userIData)

  #create value to be stored in users bucket
  usersData = {
    :handle => uinfo[:handle],
    :name => uinfo[:name],
    :avatarurl => uinfo[:avatarurl]
  }
  userRObj = initRObj(usersBucket, uid.to_s, "application/json", usersData)

  userTLObj = initRObj(@client["timelines"], uid.to_s, "application/json", "{}")

  Riak::Crdt::Counter.new(@client["users"], 'fc_'+uid.to_s)

  userRObj.store
  userRInfoObj.store
  userTLObj.store

  #link user object to corresponding user info object (just in case we need it)
  options = {:options => ['force']}
	userRObj = userRObj.reload(options).links << Riak::Link.new(userinfoBucket, uinfo[:email], "user_data")
end

def initRObj(bucket, key, ctype, data)
  rObj = bucket.new(key)
  rObj.content_type = ctype
  rObj.data = data
  return rObj;
end

def hashpassword pswd
  BCrypt::Password.create(pswd)
end

#TODO: validate
def fetchProfile userid
  begin
    profileRObj = @client["users"][userid.to_s]
    profileInfo = JSON[profileRObj.content.raw_data]
    otherInfo = {'followingcount' => @client["users"].counter("fc_"+userid.to_s).value,
      'followercount' => profileRObj.indexes["followed_by"].size,
      'user_relation' => userid == @selfid ? "is-self" : (profileRObj.indexes["followed_by"].include?(@selfid) ? "is-following" : "is-not-following")}
    return profileInfo.merge(otherInfo)
  rescue
    puts $!
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
    tweetids = JSON[tlRObj.content.raw_data]
    uprofile = getProfile(userid)
    return tweetids.map do |tweetid| 
        tweetRObj = @client["tweets"][tweetid]
        tweet = JSON[tweetRObj]
        tweet.merge(uprofile).merge({"tweetid" => tweetid})
      end
  rescue
    puts $!
  end
end

#TODO: deal with tl siblings. would be a good candidate for a Set if it worked with M/R
def postTweet(userid, tweetcontent)
  begin

    if (@client["users"].exists?(userid))
    tweet = {
      "timestamp" => Time::now().to_i(),
      "content" => tweetcontent
    } #create tweet object
    tweet_id = @client["tweets"].counter('max_tweet_id').value + Random.new.rand(@@new_id_range) 
    @client["tweets"].counter('max_tweet_id').increment(100)
    tweetRObj = initRObj(@client["tweets"], tweet_id.to_s, "application/json", tweet) #create a new RObject out of our tweet (we don't know the key yet)
    #increment the number of tweets. obviously not the best way to do this
    tweetRObj.store #put in database, will autoassign key
 
    timelineRObj = @client["timelines"].get_or_new(userid.to_s) #get timeline object or create if doesn't exist
    timelineRObj.raw_data = appendTweetToTimeline(tweet_id.to_s, timelineRObj.raw_data)
    timelineRObj.store
    else
    end
  rescue
    puts $!
    #TODO: failure posting
  end
end

def appendTweetToTimeline(tweetID, tl)
  tidlist = JSON[tl]
  tidlist['tweet_ids'].push(tweetID)
  return JSON[tidlist]
end

end


module BleaterAuth
def self.validateCredentials(email, psrd)
  begin
    client = Riak::Client.new(host: '104.131.186.243', pb_port: 10017)
    uinfoRObj = client["userinfo"][email]
    uinfo = JSON[uinfoRObj.content.raw_data]
    if (BCrypt::Password.new(uinfo['password'])== psrd)
      @selfid = uinfo['uid']
      return uinfo
    else
      return nil
    end
  rescue
    puts $!
  end
end
end
