// Program Title: Artemis2
// Author: JitteryJet
// Version: V01
// kOS Version: 1.5.1.0
// KSP Version: 1.12.5
// Description:
//    Simulation of the Artemis 2 Mission. 
//
// Notes:
//    - This script requires a matching Artemis 2 spacecraft.
//      Fuel, thrust limiting, staging and action groups have to match the
//      parameters of the script.
//    - The spacecraft starts from the KSC launchpad.
//    -
//
// Artemis 2 Flight Plan from NASA news conferences and other doco as of 23/09/2025.
//  Abbreviations: nmi-nautical mile km-kilometer ft-foot
//    SRB-Solid Rocket Booster CM-Crew Module(Orion) MECO-Main Engine Cutoff
//    ESM-European Service Module(Orion) LAS-Launch Abort System(Orion) SLS-Space Launch System
//    ICPS-Interim Cryogenic Propulsion Stage TLI-Trans Lunar Injection
//  Conversions:
//    km = nmi x 1.852
//    KSP is around 1/10th scale BUT atmospheric heights and gravity are more earth-like.
//    The KSP Mun is much closer to Kerbin than the Moon even with the 1/10 scaling.
//    KSP Minmus is more like the distance to the Moon with 1/10 scaling.
//
//  dd:hh:mm:ss   NASA Orbit    My KSP Orbit    Notes
//  -----------   ----------    ------------    -------------------------------
//  00:00:00:00                                 SRBs provide 75% of the thrust.
//  00:00:00:10   598ft         180m            Tower clear.
//                                              Start roll for crew hatch down.
//  00:00:00:18                                 Roll complete. Start pitch.
//  00:00:02:00   150,000ft                     SRB separation.
//  00:00:03:00                                 ESM fairing separation.
//  00:00:03:06                                 LAS separation.
//  00:00:08:00   15x1200nmi    28x222km        SLS Core MECO.
//                                              ICPS separation.
//                                              Solar Array deployment.
//  00:00:50:00   100x1200nmi   80x222km        Perigee raise burn at apogee.
//  00:01:50:00   0x38000nmi    0x7038km        Apogee raise and perigee lowering
//                                              burn somewhere after perigee,
//                                              a combined prograde and radial burn?
//                                              An apogee of 38,000nmi gives an
//                                              orbital period of around a day?
//                                              The 0 perigee is to ensure the
//                                              ESM burns up in the atmosphere
//                                              after separation.
//  00:03:24:00   0x38000nmi    0x7038km        ESM separation.
//                                              ESM Proximity Operations demo (2hrs).
//  00:05:24:00   0x38000nmi    0x7038km        ESM separation burn.
//  ??:??:??:??   100x38000nmi  80x7038km       Perigee raise burn at apogee.
//  ??:??:??:??   100x230000nmi 80x12000km      TLI burn at perigee.
//  ??:??:??:??                                 Lunar flyby correction burn.
//                                              Retrograde orbit.
//  ??:??:??:??   5000nmi       926km           Lunar flyby (perilune 5000-9000nmi).
//  ??:??:??:??                 40km            Perigee lowering at apogee.
//  ??:??:??:??                                 CM separation.
//                                              Atmospheric entry.
//
// Todo:
//    -
//
// Update History:
//    12/01/2026 V01  - WIP.
//                    - Created.
//                    -

@lazyglobal off.
runoncepath("Archive:/MiscFunctions V06").
local WarpType to "RAILS".
local ICPSSteeringSecs to 15.
local ESMSteeringSecs to 15.
local HudtextDelay to 20.
local HudtextStyle to 2.
local HudtextFontSize to 24.

// Launch Artemis 2 from Kerbin.
// SLS Core will MECO once the specified apoapsis is reached.
hudtext("Launch Artemis 2",HudtextDelay,HudtextStyle,HudtextFontSize,white,false).
core:part:getmodule("kOSProcessor"):doevent("Open Terminal").
runpath
  (
    "LaunchToOrbit V07.ks",
    222,                  // Orbital altitude (km).
    0,                    // Orbital inclination (degrees).
    "NORTH",              // Launch direction.
    "ZEROLIFT",           // Launch turn type "ZEROLIFT","LTS". 
    200,                  // Turn start altitude (m).
    5,                    // Turn pitchover (degrees).
    0.5,                  // Turn pitchover rate (degrees/s)
    0,                    // Linear-tangent Steering turn final angle (deg)
    0,                    // Linear-tangent Steering turn duration (s). 
    0,                    // Steering duration (s).
    WarpType,             // Warp type (NOWARP,RAILS,PHYSICS).
    20,                   // Launch countdown duration (s).
    "NOSYNC",             // Launch sync period.
    "NOCIRC"              // Circularization (CIRC,NOCIRC).
  ).

// ICPS separation.
clearscreen.
core:part:getmodule("kOSProcessor"):doevent("Close Terminal").
wait 5.
hudtext("ICPS separation",HudtextDelay,HudtextStyle,HudtextFontSize,white,false).
stage.
wait until stage:ready.
wait 2.
stage.  // Activate engines on ICPS.
sas on.
rcs on.
lock throttle to 0.1.
wait 0.5.
lock throttle to 0.
rcs off.
sas off.
unlock throttle.

// Deploy solar array.
wait 1.
hudtext("Deploy solar array",HudtextDelay,HudtextStyle,HudtextFontSize,white,false).
panels on.

// ICPS periapsis raise.
clearscreen.
wait until ship:altitude>ship:body:atm:height.
hudtext("ICPS periapsis raise",HudtextDelay,HudtextStyle,HudtextFontSize,white,false).
rcs on.
core:part:getmodule("kOSProcessor"):doevent("Open Terminal").
runpath
  (
    "ChangeOrbitApsides V01",
   "CHANGEPE",       // Apsis change name (CIRCULARIZE,CHANGEPE,CHANGEAP).
    80,               // Apsis altitude (km).
    ICPSSteeringSecs, // Steering duration (s).           
	  WarpType          // Warp type (NOWARP,RAILS,PHYSICS).
  ).
rcs off.

// ICPS apoapsis raise.
wait 1. // Workaround for phantom acceleration warping bug.
clearscreen.
hudtext("ICPS apoapsis raise",HudtextDelay,HudtextStyle,HudtextFontSize,white,false).
rcs on.
core:part:getmodule("kOSProcessor"):doevent("Open Terminal").
runpath
  (
    "ChangeOrbitApsides V01",
    "CHANGEAP",       // Apsis change name (CIRCULARIZE,CHANGEPE,CHANGEAP).
    7038,               // Apsis altitude (km).
    ICPSSteeringSecs,   // Steering duration (s).           
	  WarpType          // Warp type (NOWARP,RAILS,PHYSICS).
  ).
rcs off.

// ICPS periapsis lowering.
// The periapsis is lowered to the ground.
// This is to safety the ICPS
// by ensuring it will do an atmospheric entry
// after separation from the ESM and completion of
// the Proximity Operations demo. Leaving junk in
// orbit upsets the space-dolphins.

wait 1. // Workaround for phantom acceleration warping bug.
clearscreen.
core:part:getmodule("kOSProcessor"):doevent("Close Terminal").
hudtext("ICPS periapsis lowering",HudtextDelay,HudtextStyle,HudtextFontSize,white,false).
DoSafeWait(timestamp()+3600,WarpType).
wait 1. // Workaround for phantom acceleration warping bug.
rcs on.
lock steering to -ship:velocity:orbit.
wait ICPSSteeringSecs.
lock throttle to
  min(abs(ship:orbit:periapsis)/10+0.01,1.0).
wait until ship:orbit:periapsis <= 0.
lock throttle to 0.
rcs off.
unlock throttle.
unlock steering.

// ESM separation.
wait 1.
hudtext("ESM separation",HudtextDelay,HudtextStyle,HudtextFontSize,white,false).
stage.
wait until stage:ready.
stage.  // Activate engines on ESM.

// ESM Proximity Operations demo.

// ESM separation burn.
wait 5.
hudtext("ESM separation burn",HudtextDelay,HudtextStyle,HudtextFontSize,white,false).
sas on.
rcs on.
lock throttle to 0.1.
wait 0.5.
lock throttle to 0.
rcs off.
sas off.
unlock throttle.

// ESM periapsis raise.
wait 5.
clearscreen.
core:part:getmodule("kOSProcessor"):doevent("Open Terminal").
hudtext("ESM periapsis raise",HudtextDelay,HudtextStyle,HudtextFontSize,white,false).
rcs on.
runpath
  (
    "ChangeOrbitApsides V01",
    "CHANGEPE",       // Apsis change name (CIRCULARIZE,CHANGEPE,CHANGEAP).
    80,               // Apsis altitude (km).
    ESMSteeringSecs, // Steering duration (s).           
	  WarpType          // Warp type (NOWARP,RAILS,PHYSICS).
  ).
rcs off.

// Trans Munar Injection (TMI) calculation, burn and transfer to Mun SOI.
hudtext("Trans Munar Injection",HudtextDelay,HudtextStyle,HudtextFontSize,white,false).
clearscreen.
core:part:getmodule("kOSProcessor"):doevent("Open Terminal").
rcs on.
runpath
  (
    "TransferSimpleLambertSolver V02",
    "Mun",
    "FLYBY",
    "LOWESTDV",
    300,
    ESMSteeringSecs,
    WarpType,
    "SHOW"
  ).
rcs off.
//kuniverse:pause().

// Mun flyby correction burn.
hudtext("Mun flyby correction burn",HudtextDelay,HudtextStyle,HudtextFontSize,white,false).
clearscreen.
core:part:getmodule("kOSProcessor"):doevent("Close Terminal").
rcs on.
DoPeAdjustmentRadial(926E3,"RETROGRADE",ESMSteeringSecs).
rcs off.

// Mun flyby.
DoSafeWait(timestamp()+eta:periapsis,WarpType).
wait 1. // Workaround for phantom acceleration warping bug.
hudtext("Mun flyby. Enjoy the view!",HudtextDelay,HudtextStyle,HudtextFontSize,white,false).
wait 10.
//kuniverse:pause().

// Return to Kerbin.
hudtext("Return to Kerbin",HudtextDelay,HudtextStyle,HudtextFontSize,white,false).
DoMoonParentReturn().

local function DoPeAdjustment
  {
// Adjust the periapsis of the ship's orbit.

    parameter PeAlt.
    parameter SteeringSecs.

    if ship:orbit:periapsis > PeAlt
      {
        lock steering to -ship:velocity:orbit.
        wait SteeringSecs.
        lock throttle to
          min(abs(PeAlt-ship:orbit:periapsis)/PeAlt+0.001,1.0).
        wait until ship:orbit:periapsis < PeAlt.
      }
    else
      {
        lock steering to ship:velocity:orbit.
        wait SteeringSecs.
        lock throttle to
          min(abs(PeAlt-ship:orbit:periapsis)/PeAlt+0.001,1.0).
        wait until ship:orbit:periapsis > PeAlt.
      }
    unlock throttle.
  }
local function DoPeAdjustmentRadial
  {
// Adjust the periapsis and prograde/retrograde of the ship's orbit
// by thrusting in the radial direction.
// Notes:
//    - 
    parameter PeAlt.
    parameter OrbitType. // PROGRADE, RETROGRADE, DONTCARE
    parameter SteeringSecs.

    local NormalVec to
      vcrs(ship:position-ship:body:position,ship:velocity:orbit).
    local RadialOutVec to vcrs(ship:velocity:orbit,NormalVec).
    local MyPrograde to false.

    if OrbitType <> "PROGRADE"
      and OrbitType <> "RETROGRADE"
      and OrbitType <> "DONTCARE"
      print 0/0. // Unknown Orbit Type

    set MyPrograde to ship:orbit:inclination>=0.0 and ship:orbit:inclination<90.0.

    if (MyPrograde and OrbitType="RETROGRADE")
        or (not MyPrograde and OrbitType="PROGRADE")
      {
// This code works because KSP allows "negative" Pe values.
        lock steering to -RadialOutVec.
        wait SteeringSecs.
        lock throttle to
          min(abs(PeAlt-ship:orbit:periapsis)/PeAlt+0.001,1.0).
        wait until ship:orbit:periapsis < 0. // Pe goes below sea level.
        wait until ship:orbit:periapsis > PeAlt.
      }
    else
    if ship:orbit:periapsis > PeAlt
      {
        lock steering to -RadialOutVec.
        wait SteeringSecs.
        lock throttle to
          min(abs(PeAlt-ship:orbit:periapsis)/PeAlt+0.001,1.0).
        wait until ship:orbit:periapsis < PeAlt.
      }
    else
      {
        lock steering to RadialOutVec.
        wait SteeringSecs.
        lock throttle to
          min(abs(PeAlt-ship:orbit:periapsis)/PeAlt+0.01,1.0).
        wait until ship:orbit:periapsis > PeAlt.
      }
    lock throttle to 0.
    unlock throttle.
    unlock steering.
  }

local function DoMoonParentReturn
  {
// Return to the parent body of a moon.

    local EntryStageSeparationLeadSecs to 180. // Time before Atm Entry periapsis.
    local ParentBodyName to ship:body:name.

    wait 1. // Workaround for phantom acceleration warping bug.
    DoSafeWait(timestamp()+eta:transition,WarpType).
    wait until ship:body:name<>ParentBodyname.
    rcs on.
    DoPeAdjustment(40E3,ESMSteeringSecs).
    rcs off.
    wait 1. // Workaround for phantom acceleration warping bug.
    DoSafeWait(timestamp()+eta:periapsis-EntryStageSeparationLeadSecs,WarpType).
    rcs on.
    lock steering to -ship:velocity:surface.
    wait ESMSteeringSecs.
    hudtext("CM separation",HudtextDelay,HudtextStyle,HudtextFontSize,white,false).
    stage. // CM separation.
    wait until stage:ready.
    stage. // Deploy chutes.
    wait until ship:altitude < 15E3.
    rcs off.
    unlock steering.
  }