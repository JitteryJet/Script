// Name: LandNewGlennBoosterBoot
// Author: JitteryJet
// Version: V01
// kOS Version: 1.4.0.0
// KSP Version: 1.12.5
// Description:
//    Boot script to land a Blue Origins New Glenn booster.
//
// Notes:
//    -
//
// Todo:
//    -
//
// Update History:
//    15/05/2026 V01  - Created.
//                    -

local BoosterName to "NG Booster".

// Ensure that the booster is now the active vessel.
wait until kuniverse:activevessel=vessel(BoosterName).

// Ensure that the booster has been unpacked.
wait until ship:unpacked.

core:part:getmodule("kOSProcessor"):doevent("Open Terminal").

//kuniverse:pause().

// Land booster.
runpath("GeoCoordinates V04").
local Barge01Geo to latlng(-0.173253,-60.851403).

runpath
  (
    "LandNewGlennBooster V01",
    Barge01Geo,                       // Landing spot.
    2.2,                              // Aim Height (km).
    100,                              // Landing height (m).
    3,                                // Landing speed (m/s).
    "RAILS",                          // Warp type (NOWARP,RAILS,PHYSICS).
    "SHOW"                            // Show arrows (SHOW,NOSHOW).
  ).
