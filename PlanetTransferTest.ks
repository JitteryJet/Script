// Test the Planet Transfer script.

runpath("PlanetTransferHillClimbing V02.ks",
  "Eve",                          // Target orbital name.
  "FLYBY",                        // Encounter type (CAPTURE,FLYBY).
  3600,                           // Search step size (secs).
  30,                             // Steering duration (secs).
  "RAILS"                         // Warp type (NOWARP,RAILS,PHYSICS).
).
