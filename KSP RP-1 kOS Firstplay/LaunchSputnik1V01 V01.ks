// Name: LaunchSputnik1V01
// Author: JitteryJet
// Version: V01
// kOS Version: 1.6.0.1
// KSP Version: 1.12.5
// Description:
//    Launch the For Sputnik1 V01 rocket.
//
// Assumptions:
//    - Body is Earth.
//    - Staging Stack setup:
//      - Stage 3:  Sustainer ignition.
//      - Stage 2:  Launch Tower de-clamping.
//      - Stage 1:  Fairing jettison.
//      - Stage 0:  Satellite separation.
//    - 
//
// Notes:
//    -
//
// Todo:
//    - Finalise script.
//    -
//
// Update History:
//    22/06/2026 V01  - Created. WIP.
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

sas off.
rcs off.
clearscreen.

// Launch confirmation.
print "Program function: Sputnik 1".
print "Ship name: "+ship:name.
print "Launch heading: "+round(PitchOverHeading,1)+char(176)
  +"  "+"Pitch over: "+round(PitchOverAngle,1)+char(176).
print "Vertical speed: "+round(PitchOverVerticalSpeed,1)+" m/s".
print " ".
print "Press the ENTER key to launch".
terminal:input:clear().
wait until terminal:input:haschar
  and terminal:input:getchar()=terminal:input:enter.

print "Launching in 10 seconds".
wait 10.
set ship:control:pilotmainthrottle to 1.0.
print "Launch".

// Ignite sustainer engine.
print "Sustainer ignition".
stage.
wait until stage:ready.
wait until ship:thrust>=ship:maxthrust*0.95.

// De-clamp.
print "De-clamp".
stage.
wait until stage:ready.

// Launch straight up with roll.
print "Roll program".
//lock steering to lookdirup(ship:up:forevector,ship:facing:topvector).
lock steering to heading(PitchOverHeading,90).
wait until ship:verticalspeed>PitchOverVerticalSpeed.

// Pitch over.
print "Pitch program".
lock steering to heading(PitchOverHeading,90-PitchOverAngle).
wait until vang(ship:up:forevector,srfPrograde:forevector)>=PitchOverAngle.

// Zero lift Gravity turn.
print "Zero-lift gravity turn".
lock steering to
  heading(PitchOverHeading,90-vang(ship:up:forevector,ship:velocity:surface)).
wait until ship:thrust=0.0.
//print "Coasting".

// Wait until apogee is reached.
//wait until ship:altitude>ship:obt:apoapsis-100.

// Fairing jettison.
print "Jettison fairing".
stage.
wait until stage:ready.

// Satellite separation.
print "Satellite separation".
stage.
wait until stage:ready.

// Switch off autopilot to conserve battery.
set ship:control:pilotmainthrottle to 0.0.
unlock steering.

print "Launch completed".