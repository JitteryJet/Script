// Name: LaunchSuborbitalV01
// Author: JitteryJet
// Version: V01
// kOS Version: 1.6.0.1
// KSP Version: 1.12.5
// Description:
//    Launch the Suborbital V01 sounding rocket.
//
// Assumptions:
//    - Launched from Earth.
//    - "Tiny Tim" kickers are used.
//    - Staging Stack setup:
//      - Stage 10: Ignite kicker engine.
//                  Declamp.
//      - Stage 9:  Stage separation.
//      - Stage 8.  Ignite kicker engine.
//      - Stage 7:  Stage separation.
//      - Stage 6.  Ignite kicker engine.
//      - Stage 5:  Stage separation.
//      - Stage 4:  Ignite kicker engine.
//      - Stage 3:  Ignite sustainer engine.
//      - Stage 2:  Stage separation.
//      - Stage 1:  Payload separation.
//      - Stage 0:  Arm parachute.
//    - 
//
// Notes:
//    -
//
// Todo:
//    -
//
// Update History:
//    11/06/2026 V01  - Created.
//                    -
//
@lazyglobal off.
sas off.
rcs off.

// Peak "Tiny Tim" kicker burnout time guesstimate.
// Tune this value for optimal performance.
// The thrust has a long decay time - this causes the
// kicker to effectively coast before reaching zero
// thrust.
local KickerBurnTime to 0.5.

clearscreen.
print "Press the ENTER key to launch".
terminal:input:clear().
wait until terminal:input:haschar
  and terminal:input:getchar()=terminal:input:enter.
print "Launching in 10 seconds".
wait 10.
set ship:control:pilotmainthrottle to 1.0.
print "Launch".

// Ignite 1st kicker engine and declamp.
stage.
wait until stage:ready.
print "1st Kicker ignited".
//wait until ship:thrust=0.0.
wait KickerBurnTime.

stage.
wait until stage:ready.

// Ignite 2nd kicker engine.
stage.
wait until stage:ready.
print "2nd Kicker ignited".
//wait until ship:thrust=0.0.
wait KickerBurnTime.

stage.
wait until stage:ready.

// Ignite 3rd kicker engine.
stage.
wait until stage:ready.
print "3rd Kicker ignited".
//wait until ship:thrust=0.0.
wait KickerBurnTime.

stage.
wait until stage:ready.

// Ignite 4th kicker engine.
// This kicker engine provides ullage
// thrust to the sustainer engine.
// If the sustainer engine still suffers
// from ullage, try using a fraction of
// KickerBurnTime.
stage.
wait until stage:ready.
print "4th Kicker/Ullage ignited".
wait KickerBurnTime.

// Ignite sustainer engine.
stage.
wait until stage:ready.
print "Sustainer ignited".

// Stage separartion.
stage.
wait until stage:ready.
print "Stage separation".

wait until ship:thrust=0.0.

// Wait until apogee.
wait until ship:altitude>ship:obt:apoapsis-100.

// Payload separation.
stage.
wait until stage:ready.
print "Payload separation".

// Arm parachutes.
stage.
wait until stage:ready.
print "Parachute armed".

// End the program.
print "Launch completed".