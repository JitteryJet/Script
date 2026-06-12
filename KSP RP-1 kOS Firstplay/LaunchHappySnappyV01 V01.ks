// Name: LaunchHappySnappyV01
// Author: JitteryJet
// Version: V01
// kOS Version: 1.6.0.1
// KSP Version: 1.12.5
// Description:
//    Launch the Happy Snappy V01 sounding rocket.
//
// Assumptions:
//    - Body is Earth.
//    - Staging Stack setup:
//      - Stage 4:  Sustainer ignition.
//      - Stage 3:  Launch Tower de-clamping.
//      - Stage 2:  Fairing jettison.
//      - Stage 1:  Payload separation.
//      - Stage 0:  Parachute arming.
//    - 
//
// Notes:
//    - The fairing does not have to be jettisoned for
//      the Film Camera to work.
//
// Todo:
//    - Finalise this script.
//
// Update History:
//    12/06/2026 V01  - Created. WIP.
//                    -
//
@lazyglobal off.
// Adjust the pitch down angle to
// select the height of the gravity turn.
local PitchOverAngle to 10.0.

// The heading will influence the downrange
// distance because of the spin of the body.
// The relationship is complicated!
// Usually launching WEST will give the best downrange
// distance with V2-type rockets.
local PitchOverHeading to 180.0.

local KarmanLineHeight to 100E3.

// Adjust the payload separation height to
// increase the downrange distance slightly.
local PayloadSeparationHeight to 50E3.
sas off.
rcs off.
clearscreen.
print "Press the ENTER key to launch".
terminal:input:clear().
wait until terminal:input:haschar
  and terminal:input:getchar()=terminal:input:enter.
print "Launch heading: "+round(PitchOverHeading,1)+char(176)
  +"  "+"Pitch over: "+round(PitchOverAngle,1)+char(176).
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

// Launch straight up.
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
print "Coasting".

// Wait until apogee is reached.
wait until ship:altitude>ship:obt:apoapsis-100.

// Wait until payload separation height.
wait until ship:altitude<PayloadSeparationHeight.

// Fairing jettison.
print "Jettison fairing".
stage.
wait until stage:ready.

// Payload separation.
print "Payload separation".
stage.
wait until stage:ready.

// Arm parachute.
stage.
wait until stage:ready.
print "Parachute armed".

// Complete the launch.
print "Launch completed".