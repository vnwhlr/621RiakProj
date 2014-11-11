621RiakProject
===========
Authors: Shaleen Agarwal, Svyatoslav Sivov, Evan Wheeler

Bleater is a clone of twitter that uses the Riak database. We wrote the front-end using Ruby, on Sinatra/Rack; the interface in which we make use of the client is in riakinterface.rb. Our map-reduce queries are copied to src/js under mr.js; we've also included scripts to clear all the keys and start up the database, although we ask that you do not do this.

While you can build this yourself on ruby 2.1.0 by first pulling in the dependencies with
> gem install bundler
and then typing:
> bundle install
and then:
> rackup config.ru -p 8080

You can simply access the site at http://104.236.35.18:8080, and recommend you do this in case the above doesn't work.
We don't have a facility to look up other users yet, so here are two users with credentials you can play with to confirm that it works:

Briefly speaking, once the Sinatra app is started, it will field requests to the address and port it binds to. Once authenticated, you will be redirected to your home page at the root '/'. This corresponds to the route in app.rb get '/'. This is where your timeline is. You can examine retrieveTimeline to see how our MapReduce query for fetching the timelime works. You can also post tweets, although you'll have to log into the other account whose credentials we've given to you.
