// Name: HappySnappyV01Boot
// Author: JitteryJet
// Version: V01
// kOS Version: 1.6.0.1
// KSP Version: 1.12.5
// Description:
//    Boot script for the Happy Snappy V01 sounding rocket.
//
// Assumptions:
//    - 
//
// Notes:
//    - This script has to be located in the archive:/boot directory.
//    -
//
// Todo:
//    - Finalise this script.
//
// Update History:
//    12/06/2026 V01  - Created. Wip.
//                    -
//
@lazyglobal off.
wait until ship:unpacked.

// First launch of the rocket from a launchpad.
if ship:status = "PRELAUNCH"
  {
    core:part:getmodule("kOSProcessor"):doevent("Open Terminal").
    runpath("archive:/KSP RP-1 kOS Firstplay/LaunchHappySnappyV01 V01").
  }