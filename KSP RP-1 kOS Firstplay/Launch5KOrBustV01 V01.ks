// Name: Launch5KOrBustV01
// Author: JitteryJet
// Version: V01
// kOS Version: 1.6.0.1
// KSP Version: 1.12.5
// Description:
//    Launch the 5K Or Bust V01 sounding rocket.
//
// Assumptions:
//    - Body is Earth.
//    - Rocket achieves a suborbital trajectory.
//    - Staging Stack setup:
//      - Stage 3:  Main engine ignition.
//      - Stage 2:  Launch de-clamp.
//      - Stage 1:  Stage separation.
//      - Stage 0:  Second engine ignition.
//    - 
//
// Notes:
//    - No timewarping in the atmosphere as this can
//      affect the downrange achieved.
//    - To get the best downrange, try launching both
//      east and west. The results are different due to
//      the spin of the earth.
//
// Todo:
//    - 
//
// Update History:
//    16/06/2026 V01  - Created.
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
//    WarpParm                          NOWARP,PHYSICS,RAILS.
parameter PitchOverHeading to 90.
parameter PitchOverAngle to 20.0.
parameter WarpParm to "NOWARP".

// Constants.
local KarmanLineHeight to 100E3.
local TOAHeight to ship:body:atm:height.
local StageSeparationMinHeight to 50E3.

sas off.
rcs off.
clearscreen.

// Launch confirmation.
print "Program function: Downrange Milestones".
print "Ship name: "+ship:name.
print "Launch heading: "+round(PitchOverHeading,1)+char(176)
  +"  "+"Pitch over: "+round(PitchOverAngle,1)+char(176).
print " ".
print "Press the ENTER key to launch".
terminal:input:clear().
wait until terminal:input:haschar
  and terminal:input:getchar()=terminal:input:enter.

print "Launching in 10 seconds".
wait 10.
set ship:control:pilotmainthrottle to 1.0.

// Ignite main engine.
print "Main engine ignition".
stage.
wait until stage:ready.
wait until ship:thrust>=ship:maxthrust*0.95.

// De-clamp.
print "Liftoff".
lock steering to lookdirup(ship:up:forevector,-ship:north:forevector).
stage.
wait until stage:ready.

// Launch straight up with no roll.
print "Clear launchpad".
wait until ship:velocity:surface:mag>50.

// Pitch and roll maneuver.
print "Pitch and roll".
lock steering to heading(PitchOverHeading,90-PitchOverAngle).
wait until vang(ship:up:forevector,srfPrograde:forevector)>=PitchOverAngle.

// Zero lift Gravity turn.
print "Zero-lift gravity turn".
lock steering to srfprograde.
wait until ship:thrust=0.0.
print "MECO".

// A failsafe to prevent the stage
// separation from occurring too low
// in the atmosphere. This can happen
// with a high TWR first stage.
if ship:altitude<StageSeparationMinHeight
  {
    print "Coast to stage separation".
    wait until ship:altitude>StageSeparationMinHeight.
  }

// Stage separation.
print "Stage separation".
stage.
wait until stage:ready.

// A hack to get a bit more downrange.
// It works by moving some of the thrust
// closer to the apogee.
set ship:control:pilotmainthrottle to 0.25.

// Second engine ignition
print "Second engine ignition".
stage.
wait until stage:ready.
lock steering to prograde.
wait until ship:thrust=0.0.
print "SECO".

// Switch off autopilot functions to help conserve battery.
set ship:control:pilotmainthrottle to 0.0.
unlock steering.

// Exoatmospheric.
wait until ship:altitude>TOAHeight.
DoWarp(WarpParm,10).

// Atmospheric entry.
wait until ship:altitude<TOAHeight.
kuniverse:timewarp:cancelwarp().
print "Program completed".
kuniverse:pause().

local function DoWarp
  {
// Do a timewarp.
// Notes:
//    - 
// Todo:
//    -
parameter MyWarpMode to "PHYSICS".
parameter WarpRate to 0.

  if MyWarpMode<>"NOWARP"
    {
// A bad fix for the phantom acceleration bug.
// The wait time was determined by trial-and-error.
      wait 0.4.
      set kuniverse:timewarp:warp to 0.
      set kuniverse:timewarp:mode to MyWarpMode.
      set kuniverse:timewarp:rate to WarpRate.
      wait 0.0.
    }
  }