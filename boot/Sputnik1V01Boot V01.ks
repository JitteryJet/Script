// Name: Sputnik1V01Boot
// Author: JitteryJet
// Version: V01
// kOS Version: 1.6.0.1
// KSP Version: 1.12.5
// Description:
//    Boot script for the Sputnik 1 satellite.
//
// Assumptions:
//    - The satellite is attached to the launch vessel at liftoff.
//    - The vessel name of the satellite is not the same as the
//      vessel name of the launch vehicle.
//    -
//
// Notes:
//    - This script has to be located in the archive:/boot directory.
//    - This script will start running when the launch vehicle and satellite
//      are spawned on the launchpad.
//    -
//
// Todo:
//    -
//
// Update History:
//    28/06/2026 V01  - Created.
//                    -
//
@lazyglobal off.
wait until ship:unpacked.

local ShipName2 to ship:name.

// Wait until stage separation.
wait until ship:name<>ShipName2.

// Wait for the launch vehicle to complete
// it stage separation before switching the game focus
// to the satellite. There is only one staging
// stack per game and the in-focus vessel owns it.
wait 2.
set kuniverse:activevessel to ship.

// Only run the program once after stage separation.
if ship:status = "FLYING"
  or ship:status = "SUB_ORBITAL"
  or ship:status = "ORBITING"
  {
    core:part:getmodule("kOSProcessor"):doevent("Open Terminal").
    runoncepath
      (
        "archive:/KSP RP-1 kOS Firstplay/FlySputnik1V01 V01"
      ).
  }