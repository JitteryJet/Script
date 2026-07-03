// Name: LaunchSomeLikeItHotV04
// Author: JitteryJet
// Version: V01
// kOS Version: 1.6.0.1
// KSP Version: 1.12.5
// Description:
//    Launch the Some Like It Hot V01 launch vehicle.
//
// Assumptions:
//    - Body is Earth.
//    - The sustainer has enough delta-v to leave the atmosphere.
//    - Staging Stack setup:
//      - Stage 5:  Engine ignition.
//      - Stage 4:  Launch Tower de-clamping.
//      - Stage 3:  Booster separation.
//      - Stage 2:  Fairing jettison.
//      - Stage 1:  Payload separation.
//      - Stage 0:  Parachute arming.
//
// Notes:
//    - The launch vehicle does not roll very well, so
//      the Roll Program has been removed.
//    -
//
// Todo:
//    -
//
// Update History:
//    02/07/2026 V01  - Created.
//                    -
//
@lazyglobal off.

// Parameters:
//    PitchOverHeading                  Pitch over heading (degree).
//                                      Use to adjust the heading of the
//                                      gravity turn.
//    PitchOverAngle                    Pitch over angle (degree).
//                                      Use to adjust the start of
//                                      the gravity turn.
//    PitchOverVerticalSpeed            Pitch over vertical speed (m/s).
//                                      Vertical speed required to stabilise
//                                      low TWR rockets before pitch over.
parameter PitchOverHeading to 90.0.
parameter PitchOverAngle to 10.0.
parameter PitchOverVerticalSpeed to 25.

// Name of the engines used in the boosters.
// An assumption is other engines use different names.
local BoosterEngineName to "ROE-RD107".

local KarmanLineHeight to 100E3.

sas off.
rcs off.
clearscreen.

// Launch confirmation.
print "Program function: Launch Some Like It Hot V01".
print "Ship name: "+ship:name.
print "Launch heading: "+round(PitchOverHeading,2)+char(176)
  +"  "+"Pitch over: "+round(PitchOverAngle,2)+char(176).
print "Vertical speed: "+round(PitchOverVerticalSpeed,2)+" m/s".
print " ".
print "Press the ENTER key to launch".
terminal:input:clear().
wait until terminal:input:haschar
  and terminal:input:getchar()=terminal:input:enter.

print "Launching in 10 seconds".
wait 10.

// Ignite engines.
print "Engine ignition".
set ship:control:pilotmainthrottle to 1.0.
stage.
wait until stage:ready.
wait until ship:thrust>=ship:maxthrust*0.95.

// De-clamp.
print "De-clamp".
stage.
wait until stage:ready.

// Launch straight up.
print "Vertical ascent".
lock steering to lookdirup(ship:up:forevector,ship:facing:topvector).
wait until ship:verticalspeed>PitchOverVerticalSpeed.

// Pitch over.
print "Pitch program".
lock steering to heading(PitchOverHeading,90-PitchOverAngle).
wait until vang(ship:up:forevector,ship:facing:forevector)>PitchOverAngle*0.90.
wait until vang(ship:up:forevector,ship:velocity:surface)>PitchOverAngle.

// Zero lift Gravity turn. Low AOA.
// Lock to the heading and the surface prograde.
print "Zero-lift gravity turn".
lock steering to
  heading(PitchOverHeading,90-vang(ship:up:forevector,ship:velocity:surface)).

// Booster separation.
wait until BoosterFlameout(BoosterEngineName).
print "BECO".
wait 0.25.
print "Booster separation".
stage.
wait until stage:ready.
wait 1.

// Karman Line.
wait until ship:altitude>KarmanLineHeight.
print "Karman Line".
lock steering to ship:velocity:orbit.

// Fairing jettison.
print "Jettison fairing".
stage.
wait until stage:ready.

// Top of Atmosphere (TOA).
wait until ship:altitude>ship:body:atm:height.
print "TOA".

// BECO.
wait until ship:thrust=0.0.
print "BECO".

// Atmospheric entry
wait until ship:altitude<ship:body:atm:height.
print "Atmospheric entry".

// Payload separation.
print "Payload separation".
stage.
wait until stage:ready.

// Switch off autopilot to conserve battery.
set ship:control:pilotmainthrottle to 0.0.
unlock steering.
print "Program completed".

local function BoosterFlameout
  {
// Test for booster flameout.
// Assumptions:
//    - All the boosters have the same engine name.
//    -
// Notes:
//    - Yuck.
//    - 
// Todo:
//    -
    parameter EngName to "".

    local FlameoutCntr to 0.
    local EngCntr to 0.
    local AllFlamedout to false.
    local EngList to list().
    list engines in EngList.

    for eng in EngList
      {
        if eng:stage=ship:stagenum
          and eng:name=EngName
          {
            set EngCntr to EngCntr+1.
            if eng:flameout
              set FlameoutCntr to FlameoutCntr+1.
          }
      }
    if FlameoutCntr>0
      and FlameoutCntr=EngCntr
        set AllFlamedout to true.
    return AllFlamedout.
  }