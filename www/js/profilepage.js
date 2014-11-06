$(function(){
	
	function unfollow(unfolloweeid){$.post("/api/follow" + $.params(unfolloweeid));}
	function follow(followeeid){$.post("/api/unfollow" + $.params(followeeid));}
	function postTweet(tweetbody){$.post("/api/tweet", tweetbody);}
	
	var submitbutton = $('#tweet-submit-button').first();
		submitbutton.on('click', function(e){
			var tweetbody = $('#tweet-input-box').first().text();
			if(validateTweet(tweetbody))
			{
				postTweet(tweetbody);
			}
		});

		
	var followbutton = $('# ').first();
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
