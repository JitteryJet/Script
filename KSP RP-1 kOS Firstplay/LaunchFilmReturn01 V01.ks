// Name: LaunchFilmReturn01
// Author: JitteryJet
// Version: V01
// kOS Version: 1.6.0.1
// KSP Version: 1.12.5
// Description:
//    Launch the Film Return 01 sounding rocket.
//
// Assumptions:
//    - Staging Stack setup:
//      - Stage 3: Sustainer ignition.
//      - Stage 2: Launch Tower de-clamping.
//      - Stage 1: Fairing jettison.
//      - Stage 0: Payload separation.
//    - 
//
// Notes:
//    -
//
// Todo:
//    -
//
// Update History:
//    30/05/2026 V01  - Created.
//                    -
//
@lazyglobal off.
clearscreen.
print "Press the ENTER key to launch".
terminal:input:clear().
wait until terminal:input:haschar
  and terminal:input:getchar()=terminal:input:enter.
print "Launching in 10 seconds".
wait 10.
set ship:control:pilotmainthrottle to 1.0.
print "Launch".

// Activate sustainer.
stage.
wait until stage:ready.
print "Sustainer ignition".
wait 2.

// De-clamp launch tower.
stage.
wait until stage:ready.
print "Launch tower de-clamped".

// Pitch and roll maneuver.
lock steering to heading(270,87.0).
wait 5.
print "Pitch and roll complete".

// Zero lift Gravity turn.
lock steering to srfprograde.

// Reach required minimum altitude.
wait until ship:altitude > 100E3.

// Fairing jettison.
// Delay the fairing jettison as long as possible
// to keep the rocket stable and maximize downrange
// distance.
wait until ship:altitude < 50E3.
stage.
wait until stage:ready.
print "Fairing jettison".

// Payload separation.
wait until ship:altitude < 45E3.
stage.
wait until stage:ready.
print "Payload separation".

// Complete the launch.
print "Launch completed".