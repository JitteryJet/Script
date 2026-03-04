// Test a launch of a SpaceX Starship.
// Notes:
//  - The Ship pod and kOS processor must be tagged with the identifier "Ship".
//  - The Booster pod and kOS processor must be tagged with the identifier "Booster".
//  - This script may be ran from the Ship terminal or the Booster terminal.

local ShipName2 to "Ship".
local BoosterName to "Booster".
//local ShipProcessor to processor(ShipName).
local BoosterProcessor to processor (BoosterName).

// Set the booster kOS processor to run this boot file when it separates
// from Starship after staging.
set BoosterProcessor:bootfilename to "BootStarshipBooster".

// Unlock the launch clamps and separate the Starship
// from the Mechazilla/launchpad vessel.
//stage.

// Switch the active vessel to the ship.
// The active vessel might still be the Mechazilla/launchpad vessel.
kuniverse:forceactive(vessel(ShipName2)).

// Launch Starship to orbit. Do NOT use a countdown as the vessel
// may fall over if left for too long.
runpath
  (
    "LaunchToOrbit V07.ks",
    100,                  // Orbital altitude (km).
    0,                    // Orbital inclination (degrees).
    "NORTH",              // Launch direction.
    "LTS",               // Launch turn type "ZEROLIFT","LTS". 
    2000,                 // Turn start altitude (m).
    5,                    // Turn pitchover (degrees).
    0.5,                  // Turn pitchover rate (degrees/s)
    0,                  // Linear-tangent Steering turn final angle (deg)
    20,                  // Linear-tangent Steering turn duration (s). 
    10,                   // Steering duration (s).
    "NOWARP",            // Warp type (NOWARP,RAILS,PHYSICS).
    0,                   // Launch countdown duration (s).
    "NOSYNC",             // Launch sync period.
    "NOCIRC"              // Circularization (CIRC,NOCIRC).
  ).
clearscreen.
print ship.
print "Waiting for stage separation".
wait 0.5.
//set kuniverse:timewarp:mode to "PHYSICS".
//set kuniverse:timewarp:warp to 4.
//wait until ship:altitude > 70000.
//kuniverse:timewarp:cancelwarp().

// Reboot the booster kOS processor.
BoosterProcessor:part:getmodule("kOSProcessor"):doevent("Toggle Power").
wait 0.
BoosterProcessor:part:getmodule("kOSProcessor"):doevent("Toggle Power").
wait 0.

// Do the Stage separation.
stage.
print "Stage separation completed".

kuniverse:forcesetactivevessel(vessel(BoosterName)).
//kuniverse:pause().

// Send Ship on it's way.
lock steering to ship:velocity:orbit.
lock throttle to 1.
wait until false.