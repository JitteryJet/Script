// Name: LaunchKarmanMiranda
// Author: JitteryJet
// Version: V01
// kOS Version: 1.6.0.1
// KSP Version: 1.12.5
// Description:
//    Launch the Karman Miranda sounding rocket.
//
// Assumptions:
//    - Staging Stack setup:
//      - Stage 2: Booster activation.
//      - Stage 1: Stage separation.
//      - Stage 0: Sustainer activation.
//    - 
//
// Notes:
//    - This is a demo of a basic launch script. It usually
//      works OK, but results can be unpredictable.
//    -
//
// Todo:
//    - Finalize script.
//    -
//
// Update History:
//    29/05/2026 V01  - Created. WIP.
//                    -
//
@lazyglobal off.
clearscreen.
print "Hello world. I, i, i, i, i, i like you very much.".
print "Launching in 5 seconds".
wait 5.
set ship:control:pilotmainthrottle to 1.0.
print "Launch".

// Activate booster.
stage.
wait until stage:ready.
print "Booster activated".
wait 3.

// Stage separation.
stage.
wait until stage:ready.
print "Stage separation".

// Activate sustainer.
stage.
wait until stage:ready.
print "Sustainer activated".
print "Launch completed".