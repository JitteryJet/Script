// Name: LaunchKarmanLine
// Author: JitteryJet
// Version: V01
// kOS Version: 1.6.0.1
// KSP Version: 1.12.5
// Description:
//    Launch the Karman Line sounding rocket.
//
// Assumptions:
//    - Staging Stack setup:
//      - Stage 2:  Ignite the kicker engine.
//                  Declamp.
//      - Stage 1:  Ignite sustainer engine.
//      - Stage 0:  Stage separation.
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
//    12/06/2026 V01  - Created.
//                    -
//
@lazyglobal off.
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

// Ignite kicker engine and declamp.
stage.
wait until stage:ready.
print "Kicker ignited".
wait 1.

// Ignite sustainer engine.
stage.
wait until stage:ready.
print "Sustainer ignited".

// Stage separation
stage.
wait until stage:ready.
print "Stage separated".
print "Launch completed".