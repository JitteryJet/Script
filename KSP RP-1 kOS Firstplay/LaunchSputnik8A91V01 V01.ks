// Name: LaunchSputnik8A91V01
// Author: JitteryJet
// Version: V01
// kOS Version: 1.6.0.1
// KSP Version: 1.12.5
// Description:
//    Launch the Sputnik 8A91 V01 satellite launch vehicle.
//
// Assumptions:
//    - Body is Earth.
//    - Staging Stack setup:
//      - Stage 3:  Engine ignition.
//      - Stage 2:  Launch Tower de-clamping.
//      - Stage 1:  Booster separation
//      - Stage 0:  Satellite separation.
//    - 
//
// Notes:
//    - Completing orbital Contracts with the Sputnik 8A91 is
//      a challenge as there is no throttle control and engines
//      cannot be restarted.
//    -
//
// Todo:
//    -
//
// Update History:
//    14/07/2026 V01  - Created.
//                    -
//
@lazyglobal off.

// Parameters:
//    LaunchHeadingAng                  Launch heading angle (degree).
//                                      Compass heading of the launch.
//    PitchOverAng                      Pitch over angle (degree).
//                                      Initial pitch over to start the
//                                      gravity turn.
//    PitchOverVerticalSpeed            Pitch over vertical speed (m/s).
//                                      Vertical speed to reach before
//                                      the pitch over.
//    OrbitHeightkm                     Target orbit height (km).
//                                      This is approximate only, it will
//                                      usually result in a perigee above this
//                                      value if the launch vessel is capable.
//    FinalFlightPathAng                Final flight path angle (degree).
//                                      The flight path angle to use at the end
//                                      of the gravity turn if required. This allows
//                                      the trajectory to be steeper for low thrust-
//                                      to-weight ratios.                               
                                     
parameter LaunchHeadingAng to 90.
parameter PitchOverAng to 10.0.
parameter PitchOverVerticalSpeed to 25.
parameter OrbitHeightkm to 150.
parameter FinalFlightPathAng to 0.0.

// Load in functions from the library.
//runoncepath("archive:/library/MiscFunctions V07").

local OrbitHeight to OrbitHeightkm*1E3.

// Constants.
// Cutoff height for the zero-lift part of
// the gravity turn.
local ZeroLiftAtmosphereHeight to 20E3.

// Name of the engines used in the boosters.
// An assumption is other engines use different names.
local BoosterEngineName to "ROE-RD107".

lock NavballPitchAng to 90-vang(ship:up:forevector,ship:facing:forevector).
local SteeringDir to 0.
local PitchRot to r(0,0,0). // A 3D "rotation". Look it up in the kOS manual.
local HorizonVec to v(0,0,0).
local HorizonDir to r(0,0,0).

sas off.
rcs off.
clearscreen.

// Launch confirmation.
print "Program function: Launch Sputnik 8A91".
print "Ship name: "+ship:name.
print "Launch heading: "+round(LaunchHeadingAng,2)+char(176)
  +"  "+"Pitch over: "+round(PitchOverAng,2)+char(176).
print "Vertical speed: "+round(PitchOverVerticalSpeed,2)+" m/s".
print "Target orbit height: "+round(OrbitHeightkm,3)+" km".
print "Final flight path: "+round(FinalFlightPathAng,2)+char(176).
print " ".
print "Press the ENTER key to launch".
terminal:input:clear().
wait until terminal:input:haschar
  and terminal:input:getchar()=terminal:input:enter.

print "Launching in 10 seconds".
wait 10.
set ship:control:pilotmainthrottle to 1.0.
lock steering to heading(LaunchHeadingAng,90).

// Ignite sustainer engine.
print "Engine ignition".
stage.
wait until stage:ready.
wait until ship:thrust>=ship:maxthrust*0.95.

// De-clamp.
print "De-clamp".
stage.
wait until stage:ready.

// Launch straight up.
print "Vertical ascent and roll".
wait until ship:verticalspeed>PitchOverVerticalSpeed.

// Pitch over.
print "Pitch program".
lock steering to heading(LaunchHeadingAng,90-PitchOverAng).
wait until vang(ship:up:forevector,ship:facing:forevector)>PitchOverAng*0.95.
wait until vang(ship:up:forevector,ship:velocity:surface)>PitchOverAng.

// Zero lift Gravity turn. Low AOA.
// Lock to the heading and the surface prograde.
print "Zero-lift gravity turn".
lock steering to
  heading(LaunchHeadingAng,90-vang(ship:up:forevector,ship:velocity:surface)).

// Reduce steering losses by shifting from surface
// prograde to orbital prograde once air resistance
// is no longer important.
wait until ship:altitude>ZeroLiftAtmosphereHeight.
print "Gravity turn".
lock steering to lookdirup(ship:velocity:orbit,ship:facing:topvector).

// Booster separation.
wait until BoosterFlameout(BoosterEngineName).
print "BECO".
wait 0.1.  // Wait to ensure BECO has completed.
print "Booster separation".
stage.
wait until stage:ready.
wait 1.

if FinalFlightPathAng<>0.0
  {
// Apply the final flight path angle parameter to the
// pitch of the launch vehicle.
// Notes:
//    - The "flight path angle" is the angle between 
//      where the launch vessel is pointed and the local horizon.
//    - If you are wondering why I don't just use the
//      HEADING function it is because the heading at
//      the launchsite has no meaning in this part of the trajectory
//      and would send the launch vehicle off course a bit.
    set SteeringDir to ship:facing.
    lock steering to SteeringDir.  // Avoid putting locks in loops!
    until ship:obt:apoapsis>OrbitHeight
      {
//        print round(FinalFlightPathAng,1)+" "+round(NavballPitchAng,1).
        if NavballPitchAng>FinalFlightPathAng
          set SteeringDir to lookdirup(ship:velocity:orbit,ship:facing:topvector).
        else
          {
            set HorizonVec to vxcl(ship:up:forevector,ship:facing:forevector).
            set HorizonDir to lookDirUp(HorizonVec,ship:up:forevector).
            set PitchRot to angleAxis(-FinalFlightPathAng,HorizonDir:starvector).
            set SteeringDir to PitchRot*HorizonDir.
          }
        wait 0.
      }
  }
else
  wait until ship:obt:apoapsis>OrbitHeight.
print "1st apogee reached".

// Use the remaining fuel to raise the perigee
// while trying not to raise the apogee.
print "Perigee raise".
lock steering to vxcl(ship:up:forevector,ship:velocity:orbit).
wait until ship:thrust=0.0.
print "MECO".
//kuniverse:pause().

// Satellite separation.
wait 10.
print "Satellite separation".
stage.
wait until stage:ready.

// Switch off autopilot to conserve battery.
set ship:control:pilotmainthrottle to 0.0.
unlock steering.

print "Program completed".

local function BoosterFlameout
  {
// Test for booster flameout.
// Assumptions:
//    - All the boosters have the same engine name.
//    -
// Notes:
//    - Yuck.
//    - 
// Todo:
//    -
    parameter EngName to "".

    local FlameoutCntr to 0.
    local EngCntr to 0.
    local AllFlamedout to false.
    local EngList to list().
    list engines in EngList.

    for eng in EngList
      {
        if eng:stage=ship:stagenum
          and eng:name=EngName
          {
            set EngCntr to EngCntr+1.
            if eng:flameout
              set FlameoutCntr to FlameoutCntr+1.
          }
      }
    if FlameoutCntr>0
      and FlameoutCntr=EngCntr
        set AllFlamedout to true.
    return AllFlamedout.
  }