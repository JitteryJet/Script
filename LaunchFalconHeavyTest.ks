// Test a launch of a SpaceX Falcon Heavy.

runpath
  (
    "LaunchToOrbit V06.ks",
    100,              // Orbital altitude (km).
    0,                // Orbital inclination (degrees).
    "NORTH",          // Launch direction.
    1000,             // Turn start altitude (m).
    5,               // Turn pitchover (degrees).
    1,                // Turn pitchover rate (degrees/s).
    1000,                 // Maximum airspeed (m/s).
    30,               // Steering duration (s).
    "PHYSICS",        // Warp type (NOWARP,RAILS,PHYSICS).
    15,               // Launch countdown duration (s).
    "NOSYNC",        // Launch sync period.
    "NOCIRC"            // Skip circularization (CIRC,NOCIRC).
  ).
clearscreen.
print "Falcon Heavy waiting for booster separation".
rcs on.
lock steering to lookdirup(ship:velocity:orbit,ship:facing:topvector).
set kuniverse:timewarp:mode to "PHYSICS".
set kuniverse:timewarp:warp to 4.
wait until ship:altitude > 90000.
kuniverse:timewarp:cancelwarp().
kuniverse:pause().
stage.
kuniverse:forceactive(ship).
wait until stage:ready.
print "Falcon Heavy booster separation complete".
lock throttle to 1.
wait until false.