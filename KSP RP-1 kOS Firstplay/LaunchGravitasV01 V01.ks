// Name: LaunchGravitasV01
// Author: JitteryJet
// Version: V01
// kOS Version: 1.6.0.1
// KSP Version: 1.12.5
// Description:
//    Launch the Gravitas V01 sounding rocket.
//
// Assumptions:
//    - Body is Earth.
//    - Staging Stack setup:
//      - Stage 1:  Sustainer ignition.
//      - Stage 0:  Launch de-clamping.
//    - 
//
// Notes:
//    - The heading will influence the downrange
//      distance because of the spin of the body.
//      The relationship is complicated!
//      Usually launching WEST will give the best downrange
//      distance with sounding-type rockets.
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

local KarmanLineHeight to 100E3.

sas off.
rcs off.
clearscreen.

// Launch confirmation.
print "Ship name: "+ship:name.
print "Heading: "+round(PitchOverHeading,1)+char(176)
  +"  "+"Pitch over: "+round(PitchOverAngle,1)+char(176).
print " ".
print "Press the ENTER key to launch".
terminal:input:clear().
wait until terminal:input:haschar
  and terminal:input:getchar()=terminal:input:enter.
print "Ignition in 10 seconds".
wait 10.
set ship:control:pilotmainthrottle to 1.0.

// Ignite sustainer engine.
print "Sustainer ignition".
stage.
wait until stage:ready.
wait until ship:thrust>=ship:maxthrust*0.95.

// De-clamp.
print "De-clamp".
stage.
wait until stage:ready.

// Clear launchpad.
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

// Unlock autopilot to conserve battery.
set ship:control:pilotmainthrottle to 0.0.
unlock steering.
print "Launch completed".