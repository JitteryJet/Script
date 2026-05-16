// Name: BootNewGlennBooster
// Author: JitteryJet
// Version: V01
// kOS Version: 1.4.0.0
// KSP Version: 1.12.5
// Description:
//    Boot a Blue Origin New Glenn Booster.
//
// Notes:
//    -
//
// Todo:
//    -
//
// Update History:
//    15/05/2026 V01  - WIP. Created.
//                     -

local BoosterName to "NG Booster".

// Ensure that the booster is now the active vessel.
wait until kuniverse:activevessel=vessel(BoosterName).

// Ensure that the booster has been unpacked.
wait until ship:unpacked.

core:part:getmodule("kOSProcessor"):doevent("Open Terminal").

// Run the booster landing script
// the FIRST time the boot script is ran.
runoncepath("LandNewGlennBooster V01").