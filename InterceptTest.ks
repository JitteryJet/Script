// Test the Launch To Intercept program.

local TargetName to "Phoenix".
set target to vessel(TargetName).

runpath
  (
    "LaunchToIntercept V01.ks",
    TargetName,            // Target name.
    "LowTransferDv",      // Launch turn type (LowTransferDv,LowArrivalDv).
    50,                    // Departure time steps.
    50,                    // Transfer time steps. 
    300,                  // Search time (s). 
    3000,                 // Turn start altitude (m).
    "RAILS",              // Warp type (NOWARP,RAILS,PHYSICS).
    20,                   // Launch countdown duration (s).
    "NOSYNC",             // Launch sync period.
    "NOSHOW"                // Show Arrows (SHOW,NOSHOW).
  ).

  local MyTarget to vessel(TargetName).

  lock steering to lookDirUp(ship:velocity:orbit,-ship:up:forevector).

  wait until Mytarget:distance <= 15000.

  lock Steering to lookDirUp((Mytarget:velocity:orbit-ship:velocity:orbit),-ship:up:forevector).

  wait until Mytarget:distance <= 11000.

  ship:modulesnamed("kerbalEVA")[0]:doevent("leave seat").