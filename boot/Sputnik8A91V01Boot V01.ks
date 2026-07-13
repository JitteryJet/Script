// Name: Sputnik8A91V01Boot
// Author: JitteryJet
// Version: V01
// kOS Version: 1.6.0.1
// KSP Version: 1.12.5
// Description:
//    Boot script for the Sputnik 8A91 V01 satellite launch vehicle.
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
//    14/07/2026 V01  - Created.
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
        "archive:/KSP RP-1 kOS Firstplay/LaunchSputnik8A91V01 V01",
        90.0,
        6,
        81.0,
        200.0,
        0.0
      ).
  }