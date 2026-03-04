// Correction Burn test

runpath("PlanetTransferFormula V01.ks",
  "Duna",                         // Target orbital name
  "FLYBY",                      // Encounter type
  30,                             // Steering duration (secs)
  "RAILS"                         // Warp type 
).

runpath ("PlaneChange V02.ks",0,"Duna","DN",30,"RAILS").

