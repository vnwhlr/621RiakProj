$(function(){
	
	function unfollow(unfolloweeid){$.post("/api/unfollow?" + $.param({"unfollowee" : unfolloweeid}));}
	function follow(followeeid){$.post("/api/follow?" + $.param({"followee" : followeeid}));}
	function postBleat(bleatbody){$.post("/api/bleat", {content : bleatbody});}
	
  function validateBleat(bleatbody){return bleatbody.length > 0 && bleatbody.length<216}

	var submitbutton = $('#ldash .bleat-submit').first();
		submitbutton.on('click', function(e){
			var bleatbody = $('#ldash .bleat-input-box').first().val();
			if(validateBleat(bleatbody))
			{
				postBleat(bleatbody);
			}
		});

		
	var followbutton = $('#ldash .profile .follow-button').first();
		followbutton.on('click',
		function(e){
		if(!submitbutton.hasClass('is-self'))
		{
       //haml refuses to generate a data- attribute so WE GOTTA DO THIS THE HARD WAY
      var userclass = $(this).attr('class').split(/\s+/).filter(function(classname){return classname.lastIndexOf("userid-") != -1});
      var userid = null;
      if(!userclass.isEmpty)
      {
        userid =parseInt(userclass[0].split('-')[1])
      }
      else
      {
        console.log("failed to extract user id");
        return;
      }
			if($(this).hasClass('is-following'))
			{
        unfollow(userid);
        $(this).text("Not following")
      }
			else if($(this).hasClass('is-not-following'))
			{ 
        follow(userid);
        $(this).text("Following")
      }
			else
			{return;}
			$(this).toggleClass('is-following');
		  $(this).toggleClass('is-not-following');
		}
	});
}

);
