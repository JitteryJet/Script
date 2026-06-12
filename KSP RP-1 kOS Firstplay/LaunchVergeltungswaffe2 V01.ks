// Name: LaunchVergeltungswaffe2
// Author: JitteryJet
// Version: V01
// kOS Version: 1.6.0.1
// KSP Version: 1.12.5
// Description:
//    Launch the Vergeltungswaffe 2 ballistic missile.
//
// Assumptions:
//    - Staging Stack setup:
//      - Stage 2: Sustainer activation.
//      - Stage 1: Launch Tower de-clamping.
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
//    12/06/2026 V01  - Created.
//                    -
//
@lazyglobal off.
clearscreen.
print "Press the ENTER key to launch rocket".
terminal:input:clear().
wait until terminal:input:haschar
  and terminal:input:getchar()=terminal:input:enter.
print "Achtung!".
print "Launching in 10 seconds".
wait 10.
set ship:control:pilotmainthrottle to 1.0.
print "Launch".

// Activate sustainer.
stage.
wait until stage:ready.
print "Sustainer activated".
wait 2.

// De-clamp launch tower.
stage.
wait until stage:ready.
print "Launch tower de-clamped".

// Payload separation.
wait until ship:altitude > 140E3.
stage.
wait until stage:ready.
print "Payload separation".

// Complete the launch.
print "Launch completed".