// Name: LaunchNewGlenn
// Author: JitteryJet
// Version: V01
// kOS Version: 1.4.0.0
// KSP Version: 1.12.5
// Description:
//    Launch a Blue Origin New Glenn rocket.
//
// Notes: 
//    - The second stage vessel must be called "New Glenn"
//      and be used to name the combined vessel at launch.
//      The second stage vessel kOS processor must be tagged with the identifier "New Glenn".
//      The booster vessel must be called "NG Booster".
//      The booster kOS processor must be tagged with the identifier "NG Booster".
//      This script must be ran from the "New Glenn" kOS terminal.
//    -
//
// Todo:
//    -
//
// Update History:
//    15/05/2026 V01  - Created.
//                    -


local CombinedName to "New Glenn".
local BoosterName to "NG Booster".
local BoosterProcessor to processor(BoosterName).

// Set the name of the booster program to run after stage separation.
set BoosterProcessor:bootfilename to "LandNewGlennBoosterBoot V01".

// Launch to orbit.
runpath
  (
    "LaunchToOrbit V07.ks",
    138,                  // Orbital altitude (km).
    45.0,                  // Orbital inclination (degrees).
    "NORTH",              // Launch direction.
    "ZEROLIFT",           // Launch turn type "ZEROLIFT","LTS". 
    10000,                 // Turn start altitude (m).
    0,                    // Turn pitchover (degrees).
    0.5,                  // Turn pitchover rate (degrees/s)
    0,                    // Linear-tangent Steering turn final angle (deg)
    0,                    // Linear-tangent Steering turn duration (s). 
    10,                   // Steering duration (s).
    "NOWARP",             // Warp type (NOWARP,RAILS,PHYSICS).
    5,                    // Launch countdown duration (s).
    "NOSYNC",             // Launch sync period.
    "NOCIRC"              // Circularization (CIRC,NOCIRC).
  ).
clearscreen.
print ship.
print "Waiting for stage separation".

// Reboot the booster kOS processor.
// This will run the kOS processor's boot script.
BoosterProcessor:part:getmodule("kOSProcessor"):doevent("Toggle Power").
BoosterProcessor:part:getmodule("kOSProcessor"):doevent("Toggle Power").
wait 0.

// Stage separation.
stage.
wait until stage:ready.
print "Stage separation completed".

// Activate the second stage engines.
stage.
wait until stage:ready.
lock steering to ship:velocity:orbit.
lock throttle to 1.
print "Second stage engines started".

// Switch game focus to the booster.
kuniverse:forcesetactivevessel(vessel(BoosterName)).
//core:part:getmodule("kOSProcessor"):doevent("Close Terminal").

wait until false.