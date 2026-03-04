// Test the Planet Transfer script.

runpath("PlanetTransferFormula V01.ks",
  "Kerbal X Lander 2",                          // Target orbital name.
  "FLYBY",                        // Encounter type (CAPTURE,FLYBY).
  30,                             // Steering duration (secs).
  "RAILS"                         // Warp type (NOWARP,RAILS,PHYSICS).
).
