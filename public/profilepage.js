$(function(){
	
	function unfollow(unfolloweeid){$.post("/api/follow" + $.params(unfolloweeid));}
	function follow(followeeid){$.post("/api/unfollow" + $.params(followeeid));}
	function postTweet(tweetbody){$.post("/api/tweet", {content : tweetbody});}
	
  function validateTweet(tweetbody){return tweetbody.length > 0 && tweetbody.length<216}

	var submitbutton = $('#tweet-submit-button').first();
		submitbutton.on('click', function(e){
			var tweetbody = $('#tweet-input-box').first().val();
			if(validateTweet(tweetbody))
			{
				postTweet(tweetbody);
			}
		});

		
	var followbutton = $('#following-profile-button').first();
		followbutton.on('click',
		function(e){
		if(!submitbutton.hasClass('is-self'))
		{
			var userid = $(this).first().attr('data-userid');	
			if(submitbutton.hasClass('is-following'))
			{unfollow(userid);}
			else if(submitbutton.hasClass('is-not-following'))
			{follow(userid);}
			else
			{return;}
			submitbutton.toggleClass('is-following');
			submitbutton.toggleClass('is-not-following');
		}
	});
}

);
