// Test landing a SpaceX Falcon booster.

print "Falcon booster waiting for stage separation".
wait until ship:unpacked.
wait until ship:name <> "Falcon Heavy".
if ship:name = "Falcon Booster A"
  wait 2.
else
if ship:name = "Falcon Booster B"
  wait 20.
kuniverse:forceactive(ship).
wait 0.
stage.
wait until stage:ready.

// Land.
runpath("GeoCoordinates V03").
runpath
  (
    "LandSuperHeavyBooster V02",
    KSCLaunchpadGeo,                   // Landing spot.
//    KSCAdminBuildingGeo,
//    KSCVABHelipadWestGeo,
//    IslandAirfieldGeo,
//    IslandAirfieldTowerGeo,
//    OsealisIslandGeo,
//    KSCMonolithGeo,
//    WoomerangLaunchSite,
    240,                              // Boostback orbit duration (s)
    10,                               // Boostback flip duration (s)
    20,                               // Correction burn lead duration (s)
    20,                               // Correction burn steering duration (s)
    0,                                // Descent Height (km).
    100,                              // Landing height (m).
    5,                                // Landing speed (m/s).
    "NOWARP",                        // Warp type (NOWARP,RAILS,PHYSICS).
    "SHOW"                            // Show arrows (SHOW,NOSHOW).
  ).
