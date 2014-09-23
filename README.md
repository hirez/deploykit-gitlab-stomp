deploykit-gitlab-stomp
======================

Sink git(la|hu)b webhooks. Source STOMP messages.

What?
=====

You are lost in a maze of tiny Ruby jobs of no obvious purpose.

Github/Gitlab emit JSON packets when a thing happens. 
This turns those into STOMP messages that the rest of the Future deploy-rig understands.

Why?
====

Were one desirous of having a sequence of things happen when some code is updated, a good 
place to start is the local (or less so) code repository. Because point-to-point architecture is
ancient telco-think, we installed a common message-bus across all our servers and let the kit 
conspire. Also, we have firewalls. I understand they're quite popular with enterprises these days.

Installation.
=============

You will need:

A recent Ruby. Not 1.8.x

Bundler.

Nginx.

A STOMP broker.


'nginx-vhost' contains, remarkably enough, a Nginx vhost.
'initscript' contains, well, take a guess.

The rest of the files are as self-contained as a Ruby webswerver ever gets.

'bundle install --binstubs --path vendor/bundle' will haul down a pile of Ruby gubbins (Sinatra, STOMP).

At which point 'bin/unicorn -c ./unicorn.conf' will do something. If you were sensible and ran it as $punter, then 
it will moan about not being able to write to /var/run/unicorn - you can either change that to something you prefer, 
remembering to change the corresponding line in unicorn.conf also, create that dir and chown it to whatever user you plan
to run the job as (www-data in our case), or mangle the initscript to brickhammer it in on startup.

If you hate Unicorn and/or Nginx, then you can use whatever Ruby app-serving environment you like best. Patches welcome!

You will need to fiddle with the YAML config in order to insert your own STOMP brokers/user/password combo. You should 
probably think about changing the topic names to something that doesn't begin with 'future'.

future.git.commits is the topic that the machines watch.
future.events.gitlab is the human-readable version. There's code elsewhere to gateway that to an IRC channel. It would be 
relatively trivial to emit that data to XMPP or some dashboard malarkey that looks like a Bloomberg terminal. Ha ha! BUSINESS!
