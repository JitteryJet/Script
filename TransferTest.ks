// Test the Transfer script.

runpath
  (
    "TransferSimpleLambertSolver V01.ks",
    "Minmus",                        // Target orbital name.
    "CAPTURE",                      // Target arrival action type (CAPTURE,FLYBY).
    "LOWESTDV",                   // Search type (LOWESTDV,LOWESTTIME).
    1800,                          // Search step size (secs).
    15,                             // Steering duration (secs).
    "RAILS",                        // Warp type (NOWARP,RAILS,PHYSICS).
    "SHOW"                        // Show arrows (SHOW,NOSHOW).
  ).
