// Name: LandAnywhere
// Author: JitteryJet
// Version: V01
// kOS Version: 1.3.2.0
// KSP Version: 1.12.3
// Description:
//    Land the vessel anywhere on the SOI body.
//
// Assumptions:
//    - 
//
// Notes:
//    - This landing script is intended to be used on an airless body but it might
//      still work on a body with an atmosphere.
//    - The initial orbit can be circular, elliptical, parabolic or hyperbolic.
//    -
//
// Todo:
//    - Review time warping again, it appears to have issues.
//      in some cases.
//    - Test 45 degree inclination case.
//    - Test 90 degree inclination case.
//    - Test non-circular orbit case.
//    - Test hyperbolic orbit case.
//    - Test body with an atmosphere case, Duna, Kerbin.
//
// Update History:
//    14/02/2022 V01  - Created. WIP.
//                    -

@lazyglobal off.

// Increase IPU value to speed up scripts with a lot of calculations
// if the CPU and graphic card are good. Default is around 200.
// Max is around 2000.
//set config:ipu to 200.

// Parameter descriptions.
//    DeorbitType             "DEORBITASAP","DEORBITATPE".
//    LandingHeight           Height above ground to ready vessel for landing (m).
//    LandingSpeed            Landing speed (m/s).
//    SteeringDuration        Time to allow the vessel to steer to the burn
//                            attitude for the maneuver (s).                            
//	  WarpMode	  					  "PHYSICS","RAILS" or "NOWARP".
parameter DeorbitType to "DEORBITASAP".
parameter LandingHeight to 100.
parameter LandingSpeed to 5.
parameter SteeringDuration to 60.
parameter WarpType to "NOWARP".

// Load in library functions.
runoncepath("Delta-vFunctions V03").
runoncepath("LandAnywhereMFD V01").

local NextMFDRefreshTime to time:seconds.
local BurnStartTimeUT to time(0).
local lock StoppingDistance to CalcStoppingDistance().
lock HeightAGL TO ship:altitude-ship:geoposition:terrainheight.
local FatalError to false.
local MFDRefreshTriggerActive to true.
local StagingTriggerActive to true.

sas off.
set ship:control:mainthrottle to 0.

SetStagingTrigger().
SetMFD().
CheckForErrorsAndWarnings().
if not FatalError
  {
    SetMFDRefreshTrigger().
    deorbit().
    DescendAndLand().
  }
RemoveLocksAndTriggers().

local function deorbit
  {
// Deorbit the vessel.
// Notes:
//    - DEORBITASAP:
//        Deorbit as soon as possible.
//      DEORBITATPE:
//        Deorbit at the periapsis.
//    - The vessel is deorbited by removing the horizontal
//      orbital-frame speed less the orbital-frame speed of
//      the landing point. The result is the vessel will fall almost
//      straight down after the deorbit burn.
//    - By removing the horizontal speed only no thrust is used
//      counteracting gravity, thus minimizing gravity lossses
//      (or even eliminating them??).
//      This might result in a higher landing speed - however
//      a higher landing speed will then result in a more efficient
//      suicide burn??
//    -
//
// Todo:
//    - Test code logic using a low thrust vessel.
//

// Don't bother compensating for the orbital velocity of the surface
// when deorbiting from above an arbirary altitude - the complexity of
// the code required does not justify the results.
    local SrfVelocityCompensationLimit to 1E5.

    local BurnVec to v(0,0,0).
    local BurnDuration to 0.
    local ManeuverPointUT to time(0).
    local PositionAtVec to v(0,0,0).
    local HorizontalObtVelVec to v(0,0,0).
    local HorizontalSrfVelVec to v(0,0,0).

    if DeorbitType="DEORBITASAP"
      set ManeuverPointUT to time+SteeringDuration.
    else
    if DeorbitType="DEORBITATPE"
      set ManeuverPointUT to time+ship:obt:eta:periapsis.
    set PositionAtVec to positionat(ship,ManeuverPointUT).
    set HorizontalObtVelVec to
      vxcl(PositionAtVec-ship:body:position,velocityat(ship,ManeuverPointUT):orbit).
    if ship:body:altitudeof(PositionAtVec) < SrfVelocityCompensationLimit
      set HorizontalSrfVelVec to ship:body:geopositionof(PositionAtVec):velocity:orbit.
    set BurnVec to -(HorizontalObtVelVec-HorizontalSrfVelVec).
    set BurnDuration to
      DeltavEstBurnTime
        (
          BurnVec:mag,
          ship:mass,
          ship:availablethrust,
          ISPVesselStage()
        ).
    LandAnywhereMFD["DisplayManeuver"](BurnDuration,BurnVec:mag).
    if DeorbitType="DEORBITASAP"
      set BurnStartTimeUT to ManeuverPointUT.
    else
    if DeorbitType="DEORBITATPE"
      {
        set BurnStartTimeUT to ManeuverPointUT-BurnDuration/2.
        if time > BurnStartTimeUT-SteeringDuration
          {
            LandAnywhereMFD["DisplayError"]("Not enough time. Calculated burn start time will be missed.").
//            print 0/0.
          }
      }   

    if WarpType = "NOWARP"
      wait BurnStartTimeUT:seconds-SteeringDuration-time:seconds.
    else
      {
        set kuniverse:timewarp:mode to WarpType.
        kuniverse:timewarp:warpTo(BurnStartTimeUT:seconds-SteeringDuration).
        wait BurnStartTimeUT:seconds-SteeringDuration-time:seconds.
        wait until kuniverse:timewarp:issettled.
      }
    LandAnywhereMFD["DisplayFlightstatus"]("Steering").
    wait until time > BurnStartTimeUT-SteeringDuration.
    lock steering to
      lookdirup(BurnVec,ship:facing:topvector).
    wait until time > BurnStartTimeUT.
    LandAnywhereMFD["DisplayFlightstatus"]("Deorbit burn").
    lock throttle to 1.
    wait until time > BurnStartTimeUT+BurnDuration.
    lock throttle to 0.
    unlock steering.
    set BurnStartTimeUT to time(0).
  }

local function DescendAndLand
  {
// Descend to the surface and land.
// Notes:
//    - This code is a hack. It is difficult to design an
//      elegant Suicide Burn control scheme that handles
//      all the contingencies well.
//    - Landing Height provides a margin of error for
//      the suicide burn calculations.
//    -
//
// Todo:
//    - 

    local BBox to 0.
    local SpeedPID to PIDLoop().
    set SpeedPID:kp to 0.1.
    set SpeedPID:ki to 0.1.
    set SpeedPID:minoutput to 0.
    set SpeedPID:maxoutput to 1.

    LandAnywhereMFD["DisplayFlightstatus"]("Descent").

// Change the height above the ground from the COM of the vessel
// to the bottom of the vessel. This is delayed as long as possible
// so the vessel configuration and bounding box are in their final
// state (ignoring the landing legs deployment).
    set BBox to ship:bounds.
    lock HeightAGL to BBox:bottomaltradar.

// Steer into more-or-less the correct attitude for the suicide
// burn before any warping to reduce any post-warp lash.
    lock steering to lookdirup(-ship:velocity:surface,ship:facing:topvector).
    wait until vang(ship:facing:forevector,steeringManager:target:forevector) < 1.
    wait until HeightAGL < StoppingDistance+LandingHeight.
    LandAnywhereMFD["DisplayFlightstatus"]("Suicide burn").
// This lock is a hack to regulate the suicide burn throttle to
// keep the Stopping Distance and height above ground roughly
// the same. 
    lock throttle to (StoppingDistance+LandingHeight)/HeightAGL.
    legs on.
    wait until StoppingDistance-LandingHeight <= 0.
    LandAnywhereMFD["DisplayFlightstatus"]("Landing").
    set SpeedPID:setpoint to -LandingSpeed.
    lock throttle to SpeedPID:update(time:seconds,ship:verticalspeed).
    wait until ship:status="LANDED".
    LandAnywhereMFD["DisplayFlightstatus"]("Landed").
    unlock throttle.
// Stabilize the vessel.
    wait 2.
    unlock steering.
  }

local function CalcStoppingDistance
  {
// Calculate the vertical stopping distance.
// Notes:
//    - Assumption: All available thrust is used.
//    - Assumption: A more-or-less vertical descent,
//      especially just before landing.
//    - The code allows for some tilt of the vessel
//      from vertical, the tilt being used to
//      control sideways speed during the landing.
//    - 
// Todo:
//    -
//    
    local GravAcc to 0.
    local MaxVerticalAcc to 0.
    local VerticalStoppingDistance to 0.

    set GravAcc to ship:body:mu/(ship:body:radius+ship:altitude)^2.
    set MaxVerticalAcc to vdot(ship:facing:forevector,ship:up:forevector)*ship:availablethrust/ship:mass-GravAcc.
    set VerticalStoppingDistance to ship:verticalSpeed^2/(2*MaxVerticalAcc).

    LandAnywhereMFD["DisplayDiagnostic"](round(GravAcc,2),round(MaxVerticalAcc,2)).

    return VerticalStoppingDistance.
  }

local function SetMFD
  {
// Set the Multi-function Display.
// Notes:
//    -
// Todo:
//    -
    clearScreen.
    set terminal:width to 56.
    set terminal:height to 23.
    LandAnywhereMFD["DisplayLabels"]
      (
        ship:name,
        DeorbitType,
        LandingHeight,
        LandingSpeed
      ).
  }

local function SetMFDRefreshTrigger
  {
// Refresh the Multi-function Display.
// Notes:
//		- Experimental. I have no idea what the physics tick cost will be.
// Todo:
//		- Try to figure out how often this needs to run.
//    - It should be easy enough to add logic to skip a number of physics
//      ticks before a refresh is done if necessary.
    local RefreshInterval to 0.1.
    when NextMFDRefreshTime < time:seconds
    then
      {
        LandAnywhereMFD["DisplayRefresh"]
         (
          ship:verticalspeed,
          ship:altitude,
          HeightAGL,
          StoppingDistance,
          ship:obt:apoapsis,
          ship:obt:periapsis,
          ship:obt:eccentricity,
          BurnStartTimeUT:seconds,
          time:seconds
         ).
        set NextMFDRefreshTime to NextMFDRefreshTime+RefreshInterval.
        return MFDRefreshTriggerActive.
      }
  }

local function SetStagingTrigger
  {
// Stage automatically when the fuel in the stage runs out.
// Notes:
//		-
// Todo:
//		-
    when
      ship:maxthrust = 0
      or (stage:liquidfuel = 0 and stage:solidfuel = 0)
    then
      {
        stage.
        until stage:ready
          {wait 0.}
        if stage:number > 0
          return StagingTriggerActive.
        else
          return false.
      }
  }

local function CheckForErrorsAndWarnings
  {
// Check for errors and warnings.
// Notes:
//    -
// Todo:
//    - 

    if DeorbitType<>"DEORBITASAP"
      and DeorbitType<>"DEORBITATPE"
      {
        LandAnywhereMFD["DisplayError"]("Deorbit type is invalid").
        set FatalError to true.
      }
  }

local function RemoveLocksAndTriggers
{
// Remove locks and triggers.
// Notes:
//    - Guarantee unneeded locks and triggers are removed before
//      any following script is run. THROTTLE, STEERING and
//      triggers are global and will keep processing
//      until control is returned back to the terminal program -
//      this is relevant if this script is ran using
//      RUNPATH from another script before exiting to the
//      terminal program.
// Todo:
//    -

  set StagingTriggerActive to false.
  set MFDRefreshTriggerActive to false.
  unlock throttle.
  unlock steering.
//  unlock HeightAGL.
  wait 0.
}