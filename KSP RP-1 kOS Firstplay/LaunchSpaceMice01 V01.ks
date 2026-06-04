// Name: LaunchFilmReturn01
// Author: JitteryJet
// Version: V01
// kOS Version: 1.6.0.1
// KSP Version: 1.12.5
// Description:
//    Launch the Space Mice 01 sounding rocket.
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
//    - Finalize this script.
//
// Update History:
//    04/06/2026 V01  - Created. WIP.
//                    -
//
@lazyglobal off.
local KaramLineASL to 100E3.
sas off.
rcs off.
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

// Fly straight up.
lock steering to ship:up.
print "Fly straight up".

// Reach required minimum altitude.
wait until ship:altitude > KaramLineASL.
set ship:control:pilotmainthrottle to 0.0.
unlock steering.
print "Automatic steering completed".

// Fairing jettison.
stage.
wait until stage:ready.
print "Fairing jettison".

// Payload separation.
wait until ship:altitude < KaramLineASL.
stage.
wait until stage:ready.
print "Payload separation".

// Complete the launch.
print "Launch completed".