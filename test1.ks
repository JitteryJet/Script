@lazyglobal off.
runoncepath("Archive:/MiscFunctions V06").
local WarpType to "RAILS".
local ICPSSteeringSecs to 15.
local ESMSteeringSecs to 15.
local HudtextDelay to 20.
local HudtextStyle to 2.
local HudtextFontSize to 24.

// Trans Munar Injection (TMI) calculation, burn and transfer to Mun SOI.
hudtext("Trans Munar Injection",HudtextDelay,HudtextStyle,HudtextFontSize,white,false).
DoSafeWait(timestamp()+eta:periapsis-504,WarpType).
rcs on.
//core:part:getmodule("kOSProcessor"):doevent("Open Terminal").
runpath
  (
    "TransferSimpleLambertSolver V02",
    "Mun",
    "FLYBY",
    "NOW",
    50,
    -7200,
    15,
    WarpType,
    "SHOW"
  ).
rcs off.
//core:part:getmodule("kOSProcessor"):doevent("Close Terminal").
wait 1. // Workaround for phantom acceleration warping bug.

DoSafeWait(timestamp()+eta:transition,WarpType).
wait until ship:obt:transition <> "ENCOUNTER".

// Mun flyby correction burn.
hudtext("Mun flyby correction burn",HudtextDelay,HudtextStyle,HudtextFontSize,white,false).
rcs on.
DoPeAdjustmentRadial(926E3,"RETROGRADE",ESMSteeringSecs).
rcs off.

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