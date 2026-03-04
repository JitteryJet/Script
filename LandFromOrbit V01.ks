// Name: LandFromOrbit
// Author: JitteryJet
// Version: V01
// kOS Version: 1.3.2.0
// KSP Version: 1.11.2
// Description:
//    Land on a body from orbit.
//
// Assumptions:
//    - The orbit is circular.
//    - The body has no atmosphere.
//
// Notes:
//    - 
//
// Todo:
//    - Test using a low available thrust.
//    - Add landing on a body with an atmosphere.
//
// Update History:
//    26/03/2021 V01  - Created. WIP.
//                    -
@lazyglobal off.
// Parameter descriptions.
//    SteeringDuration        Time to allow the vessel to steer to the burn
//                            attitude for the maneuver (s).                            
//	  WarpMode	  					  "PHYSICS","RAILS" or "NOWARP".

parameter SteeringDuration to 60.
parameter WarpMode to "NOWARP".

// Load in library functions.
runoncepath("Delta-vFunctions V02").
runoncepath("LandFromOrbitMFD V01").

local NextMFDRefreshTime to time:seconds.
local BurnStartTimeUT to time(0).
local ImpactTimeUT to time(0).
local FatalError to false.
local MFDRefreshTriggerActive to true.
local StagingTriggerActive to true.

// Other initialisations.
sas off.
set ship:control:mainthrottle to 0.
lock throttle to 0.
SetStagingTrigger().
  
// Main program.
SetMFD().
CheckForErrorsAndWarnings().

if not FatalError
  {
    LandFromOrbitMFD["DisplayFlightStatus"]("Orbiting").
    SetMFDRefreshTrigger().
    lights on.
    legs on.
    deorbit().
    SuicideBurn().
  }

//wait until false.

RemoveLocksAndTriggers().

local function deorbit
  {
// Deorbit the vessel.
// Notes:
//    -
// Todo:
//    - 

//    local BurnDeltav to ship:velocity:orbit:mag.
    local BurnDeltav to ship:velocity:surface:mag.
    local BurnDuration to
      DeltavEstBurnTime
        (
          BurnDeltav,
          ship:mass,
          ship:availablethrust,
          ISPVesselStage()
        ).

    set BurnStartTimeUT to time+SteeringDuration.
    LandFromOrbitMFD["DisplayManuever"](BurnDuration,BurnDeltav).
    LandFromOrbitMFD["DisplayFlightstatus"]("Deorbit wait").
    until time > BurnStartTimeUT-SteeringDuration
      wait 0.
    local BurnDeltavVec to -velocityat(ship,BurnStartTimeUT):surface.
    lock steering to BurnDeltavVec.
    until time > BurnStartTimeUT
      wait 0.
    LandFromOrbitMFD["DisplayFlightstatus"]("Deorbiting").
    lock throttle to 1.
    until time > BurnStartTimeUT+BurnDuration
      wait 0.
    lock throttle to 0.
    unlock steering.
    set BurnStartTimeUT to time(0).
    LandFromOrbitMFD["DisplayFlightstatus"]("Deorbit fin").

  }

local function SuicideBurn
  {
// Do a suicide burn.
// Notes:
//    - There is no equation for a suicide burn as far
//      as I can tell. This solution is a hack.
//    - Assumption is the vessel has only small amounts of sidewise
//      velocity relative to the surface, and is in free-fall.
//    - The method used is convervative and errs on the side of safety
//      wrt to fuel economy.
//      - Do a Suicide Burn and bring vessel to a stop when
//        the "time to impact" equals the amount of time required
//        to apply that delta-v. The "time to impact" is only a rough
//        estimate.
//      - Then do a Hover Burn for the rest of the distance. 
// Todo:
//    - Find a better method for estimating "time to impact", the
//      current method is bollocks and wastes fuel by starting the
//      Suicide Burn too early.

    local completed to false.
    local BurnDuration to 0.
    local BurnDeltav to 0.
    local VelocitySign to 0.
// The new-fangled "bounding box" of a vessel. Call it once only
// as it is reusuable.
    local BBox to ship:bounds.
    local ConstantSpeedPID to PIDLoop().
    set ConstantSpeedPID:kp to 0.1.
//    set ConstantSpeedPID:ki to 1e-3.
    set ConstantSpeedPID:minoutput to 0.
    set ConstantSpeedPID:maxoutput to 1.

    LandFromOrbitMFD["DisplayManuever"](0,0).
    LandFromOrbitMFD["DisplayFlightstatus"]("Suicide wait").
    lock steering to ship:srfretrograde.
    until completed
      {
        set BurnDeltav to ship:velocity:surface:mag.
        set BurnDuration to
          DeltavEstBurnTime
            (
              BurnDeltav,
              ship:mass,
              ship:availablethrust,
              ISPVesselStage()
            ).
        LandFromOrbitMFD["DisplayManuever"](BurnDuration,BurnDeltav).
        if BurnDeltav >= 1
          {
            set ImpactTimeUT to time+BBox:BottomAltRadar/BurnDeltav.
            if ImpactTimeUT < time+BurnDuration
              {
                LandFromOrbitMFD["DisplayFlightstatus"]("Suicide burn").
                lock throttle to 1.
                until time > ImpactTimeUT
                  wait 0.
                set ImpactTimeUT to time(0).
                lock steering to ship:up.
                LandFromOrbitMFD["DisplayFlightstatus"]("Hover burn").
                set ConstantSpeedPID:setpoint to -15. // -15 m/s downwards. 
                lock throttle to
                  ConstantSpeedPID:update
                    (time:seconds,ship:velocity:surface:mag*VelocitySign).
                until BBox:bottomaltradar < 1
                  {
                    if vdot(ship:velocity:surface,ship:up:forevector) > 0
                      set VelocitySign to 1.
                    else
                      set VelocitySign to -1.
                    if BBox:bottomaltradar < 50
                      set ConstantSpeedPID:setpoint to -5.
                    wait 0.  
                  }
                set completed to true.
              }
          }
        wait 0.
      }
    LandFromOrbitMFD["DisplayFlightstatus"]("Suicide fin").
    wait 5.  // Stabilize for a short period of time.
  }

local function SetMFD
  {
// Set the Multi-function Display.
// Notes:
//    -
// Todo:
//    -
    clearScreen.
    set terminal:width to 50.
    set terminal:height to 20.
    LandFromOrbitMFD["DisplayLabels"](ship:name).
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
        LandFromOrbitMFD["DisplayRefresh"]
         (
          ship:apoapsis,
          ship:periapsis,
          BurnStartTimeUT:seconds,
          time:seconds,
          ImpactTimeUT:seconds
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
//    - I picked "reasonable" values to check for.
// Todo:
//    - Test the tolerance of the checks ie run tests to calibrate
//      the values.

    if ship:orbit:eccentricity > 0.1
      LandFromOrbitMFD["DisplayError"]("This orbit is not circular").

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
  wait 0.
}