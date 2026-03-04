// Test Starship.
//

// Load in library functions.
runoncepath("GeoCoordinates V01.ks").

runpath ("StarshipAutopilot V06.ks",
  "HIGHALTITUDETEST",            // Autopilot mode.
  KSCLaunchpadGeo,     // Landing spot.
  "NOWARP",                 // Warp type.
  5,                        // Launch countdown duration.
  0).                       // Launch sync period.
