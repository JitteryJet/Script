// Launch script for the "Karman Miranda" sounding rocket.

clearscreen.
print "Hello world. I, i, i, i, i, i like you very much.".
print "Launch in 5 seconds".
wait 5.
set ship:control:pilotmainthrottle to 1.0.
print "Launching".
stage.
wait until stage:ready.
print "Rocket staged".
wait 3.
stage.
wait until stage:ready.
print "Rocket staged".
wait 5.
print "I am done. Go away now".