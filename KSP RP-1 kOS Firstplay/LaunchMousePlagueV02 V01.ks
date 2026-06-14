// Name: LaunchMousePlagueV02
// Author: JitteryJet
// Version: V01
// kOS Version: 1.6.0.1
// KSP Version: 1.12.5
// Description:
//    Launch the Mouse Plague V02 sounding rocket.
//
// Assumptions:
//    - Body is Earth.
//    - The first stage has enough delta-v to reach the
//      top of the atmosphere.
//    - Staging Stack setup:
//      - Stage 5:  Main engine ignition.
//      - Stage 4:  Launch de-clamp.
//      - Stage 3:  Jettison fairing.
//      - Stage 2:  Stage separation.
//      - Stage 1:  Secondary engine ignition.
//      - Stage 0:  Parachute arming.
//    - 
//
// Notes:
//    -
//
// Todo:
//    - 
//
// Update History:
//    14/06/2026 V01  - Created.
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
parameter PitchOverHeading to 90.
parameter PitchOverAngle to 10.0.

// Constants.
local KarmanLineHeight to 100E3.

sas off.
rcs off.
clearscreen.
// Launch confirmation.
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
print "Launch".

// Ignite main engine.
print "Main engine ignition".
stage.
wait until stage:ready.
wait until ship:thrust>=ship:maxthrust*0.95.

// De-clamp.
print "Liftoff".
stage.
wait until stage:ready.

// Launch straight up with no roll.
print "Clear launchpad".
lock steering to lookdirup(ship:up:forevector,ship:facing:topvector).
wait 1.

// Pitch and roll maneuver.
print "Pitch and roll".
lock steering to heading(PitchOverHeading,90-PitchOverAngle).
wait 15.

// Zero lift Gravity turn.
print "Zero-lift gravity turn".
lock steering to srfprograde.
wait until ship:thrust=0.0.
print "MECO".

// Coast to the top of the atmosphere.
print "Coasting to TOA".
wait until ship:altitude>ship:body:atm:height.

// Jettison fairing.
print "Jettison fairing".
stage.
wait until stage:ready.

// Stage separation.
print "Stage separation".
stage.
wait until stage:ready.

// Secondary engine ignition.
print "Secondary engine ignition".
lock steering to srfPrograde.
stage.
wait until stage:ready.
wait until ship:thrust=0.0.
print "SECO".

// Arm parachute.
stage.
wait until stage:ready.
print "Parachute armed".

// Switch off autopilot to conserve battery.
set ship:control:pilotmainthrottle to 0.0.
unlock steering.

print "Launch completed".