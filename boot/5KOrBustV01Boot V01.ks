// Name: 5KOrBustV01Boot
// Author: JitteryJet
// Version: V01
// kOS Version: 1.6.0.1
// KSP Version: 1.12.5
// Description:
//    Boot script for the 5K Or Bust V01 sounding rocket.
//
// Assumptions:
//    - 
//
// Notes:
//    - This script has to be located in the archive:/boot directory.
//    -
//
// Todo:
//    - 
//
// Update History:
//    16/06/2026 V01  - Created.
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
        "archive:/KSP RP-1 kOS Firstplay/Launch5KOrBustV01 V01",
        82.5,
        21.0,
        "RAILS"
      ).
  }