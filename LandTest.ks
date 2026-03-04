// Test the landing script.

runpath("GeoCoordinates V01").

runpath
  (
    "LandSimpleLambertSolver V02.ks",
    MunArch1Geo,         // Target landing spot geoposition.
//    MunNearArch1Geo,
//    NeilArmstrongMemorialGeo,
//      MunFlyingSaucerGeo,
//    MunLandingPad03Geo,
    "LOWDV",                          // Search type (ASAP,LOWDV,LOWTIME).
    60,                              // Search steps.
    300,                              // Max search time allowed (s).
    2,                                // Descent Height (km).
    20,                               // Landing height (m).
    3,                                // Landing speed (m/s).
    20,                               // Steering duration (secs).
    "RAILS",                        // Warp type (NOWARP,RAILS,PHYSICS).
    "NOSHOW"                          // Show arrows (SHOW,NOSHOW).
  ).
