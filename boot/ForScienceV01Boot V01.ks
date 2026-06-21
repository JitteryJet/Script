// Name: ForScienceV01Boot
// Author: JitteryJet
// Version: V01
// kOS Version: 1.6.0.1
// KSP Version: 1.12.5
// Description:
//    Boot script for the For Science V01 sounding rocket.
//
// Assumptions:
//    - 
//
// Notes:
//    - This script has to be located in the archive:/boot directory.
//    -
//
// Todo:
//    - Finalise the script.
//    -
//
// Update History:
//    21/06/2026 V01  - Created. WIP
//                    -
//
@lazyglobal off.
wait until ship:unpacked.

// First launch of the rocket from a launchpad.
if ship:status = "PRELAUNCH"
  {
    core:part:getmodule("kOSProcessor"):doevent("Open Terminal").
    runpath
      (
        "archive:/KSP RP-1 kOS Firstplay/LaunchForScienceV01 V01",
        0.0,
        0.0
      ).
  }