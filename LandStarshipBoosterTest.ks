// Test landing a SpaceX Starship booster.

print ship.
wait 0.

// Land.
runpath("GeoCoordinates V04").
//global KSCLaunchpadGeo2 to latlng(-0.0975,-74.5570).
runpath
  (
    "LandStarshipBooster V03",
    KSCLaunchpadGeo,                   // Landing spot.
//    KSCAdminBuildingGeo,
//    KSCVABHelipadWestGeo,
//    IslandAirfieldGeo,
//    IslandAirfieldTowerGeo,
//    OsealisIslandGeo,
//    KSCMonolithGeo,
//    WoomerangLaunchSite,
    240,                              // Boostback orbit duration (s)
    20,                               // Boostback flip duration (s)
    30,                               // Correction burn lead duration (s)
    60,                               // Correction burn steering duration (s)
    0,                                // Descent Height (km).
    200,                              // Landing height (m).
    5,                                // Landing speed (m/s).
    "NOWARP",                        // Warp type (NOWARP,RAILS,PHYSICS).
    "SHOW"                            // Show arrows (SHOW,NOSHOW).
  ).
