// Name: Multistage01Boot
// Author: JitteryJet
// Version: V01
// kOS Version: 1.6.0.1
// KSP Version: 1.12.5
// Description:
//    Boot script for the Multistage 01 rocket
//
// Assumptions:
//    - The command pod in the last stage
//      of the rocket runs this script.
//      This ensure the correct stage is in game focus
//      after staging. 
//
// Notes:
//    - This script has to be located in the archive:/boot directory.
//    -
//
// Todo:
//    - Finalize this script.
//
// Update History:
//    07/06/2026 V01  - Created. WIP.
//                    -
//
@lazyglobal off.
wait until ship:unpacked.

// First launch of the rocket from a launchpad.
if ship:status = "PRELAUNCH"
  {
    core:part:getmodule("kOSProcessor"):doevent("Open Terminal").
    runpath("archive:/KSP RP-1 kOS Firstplay/LaunchMultistage01 V01").
  }