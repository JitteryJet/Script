// Name: LaunchMultistage01
// Author: JitteryJet
// Version: V01
// kOS Version: 1.6.0.1
// KSP Version: 1.12.5
// Description:
//    Launch the Multistage 01 rocket.
//
// Assumptions:
//    - The command pod in the last stage
//      of the rocket runs this script.
//      This ensure the correct stage is in game focus
//      after staging.
//    - KSP Staging Stack setup:
//      - Stage 7: Stage 1 ignition.
//      - Stage 6: De-clamp.
//      - Stage 5: Stage 2 separation.
//      - Stage 4: Stage 2 spin up.
//      - Stage 3: Stage 2 ullage.
//      - Stage 2. Stage 2 ignition.
//      - Stage 1: Stage 3 separation.
//      - Stage 0: Stage 3 ignition.
//    - Body is KSP RP-1 Earth.
//    - Stage 1 has thrust vectoring.
//    - Stage 2 is spin-stabilized.
//
// Notes:
//    -
//
// Todo:
//    -
//
// Update History:
//    12/06/2026 V01  - Created. WIP.
//                    -
//
@lazyglobal off.
local PitchHeading to 90.0.
local PitchAngle to 5.0.
sas off.
rcs off.
clearscreen.
print "Press the ENTER key to launch".
terminal:input:clear().
wait until terminal:input:haschar
  and terminal:input:getchar()=terminal:input:enter.
print "Launch heading: "+round(PitchHeading,1)+char(176)
  +"  "+"Pitch over: "+round(PitchAngle,1)+char(176).
print "Launching in 10 seconds".
wait 10.
set ship:control:pilotmainthrottle to 1.0.

// Stage 1 ignition.
print "Stage 1 ignition".
stage.
wait until stage:ready.
wait 2.5.

// De-clamp.
print "De-clamp".
stage.
wait until stage:ready.

// Launch.
print "Launch".
lock steering to ship:up.
wait 50.

// Pitch and roll maneuver.
print "Pitch and roll".
lock steering to heading(PitchHeading,90-PitchAngle).
wait 10.

// Start Zero-lift gravity turn.
print "Start Zero-lift gravity turn".
lock steering to srfprograde.

// Continue the Zero-lift gravity turn until
// stage burnout.
wait until ship:thrust = 0.

// Stage 2 separation.
print "Stage 2 separation".
stage.
wait until stage:ready.
wait 0.1.

// Spin up stage 2.
print "Stage 2 spin-up".
stage.
wait until stage:ready.
wait 1.0.

// Stage 2 ullage.
print "Stage 2 ullage".
stage.
wait until stage:ready.
wait 0.5.

// Stage 2 ignition.
print "Stage 2 ignition".
stage.
wait until stage:ready.

// Wait until stage burnout.
wait until ship:thrust = 0.

// Stage 3 separation.
print "Stage 3 separation".
stage.
wait until stage:ready.
wait 0.5.

// Stage 3 ignition.
print "Stage 3 ignition".
stage.
wait until stage:ready.

// Shut down engine half way.
wait 20.
set ship:control:pilotmainthrottle to 0.0.

// Restart engine at top part of orbit.
wait until ship:altitude > (ship:obt:apoapsis-500).
set ship:control:pilotmainthrottle to 1.0.

// Complete the launch.
print "Launch completed".