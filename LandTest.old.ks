// Test the landing script.

runpath("GeoCoordinates V01").

//kuniverse:quickloadfrom("Neil Armstrong Memorial test case 02").

set kuniverse:timewarp:mode to "RAILS".
kuniverse:timewarp:warpTo(41472).
wait until kuniverse:timewarp:warp = 0 and ship:unpacked.

runpath
  (
    "LandSimpleLambertSolver V01.ks",
    NeilArmstrongMemorialGeo,       // Target landing spot geoposition.
    "LOWESTDV",                   // Search type (LOWESTDV,LOWESTTIME).
    360,                          // Search steps.
    20,                             // Steering duration (secs).
    "RAILS",                        // Warp type (NOWARP,RAILS,PHYSICS).
    "NOSHOW"                        // Show arrows (SHOW,NOSHOW).
  ).

//set config:ipu to 200.
set kuniverse:timewarp:mode to "RAILS".
local waitto to timestamp()+802.
kuniverse:timewarp:warpTo(waitto:seconds).
wait until kuniverse:timewarp:warp = 0 and ship:unpacked.
wait until timestamp() > waitto.
runpath
  (
    "LandAnywhere V01",
    "DEORBITASAP",                    // Deorbit type (DEORBITASAP,DEORBITATPE).
    20,                               // Landing height (m).
    3,                                // Landing speed (m/s).
    20,                               // Steering duration (secs).
    "NOWARP"                         // Warp type (NOWARP,RAILS,PHYSICS).
  ).
