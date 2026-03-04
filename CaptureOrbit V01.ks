// Name: CaptureOrbit
// Author: JitteryJet
// Version: V01
// kOS Version: 1.3.2.0
// KSP Version: 1.11.2
// Description:
//    Perform an orbit insertion maneuver to put the vessel in a capture orbit around
//    a body.
//
// Assumptions:
//    - This vessel's orbit is still outside the SOI of the capture body
//      ie the current orbit patch ends in a transition of ENCOUNTER.
//
// Notes:
//    - I decided to not do any course corrections
//      outside the SOI. This makes the code simpler and
//      bypasses issues with inaccuracies due to the SOI
//      transition conversions KSP has to do.
//    - The encounter may be retrograde, and is treated the same as a prograde encounter.
//      The result will be a retrograde capture orbit.
//
// Todo:
//    - Treat a retrograde encounter as a special case, and force it into
//      a prograde encounter. 
//    - Handle case where there is already a periapsis and it needs to
//      be lowered to the safe periapsis.
//
// Update History:
//    27/03/2021 V01  - Created. WIP.
//                    -
@lazyglobal off.
// Parameter descriptions.
//    SteeringDuration        Time to allow the vessel to steer to the burn
//                            attitude for the maneuver (s).                            
//	  WarpType	  					  "PHYSICS","RAILS" or "NOWARP".

parameter SteeringDuration to 60.
parameter WarpType to "NOWARP".

// Load in library functions.
runoncepath("MiscFunctions V02").
runoncePath("Delta-vFunctions V02").
runoncepath("CaptureOrbitMFD V01").

local NextMFDRefreshTime to time:seconds.
local BurnStartTimeUT to time(0).
local FatalError to false.
local MFDRefreshTriggerActive to true.
local StagingTriggerActive to true.
local SOITransitionDone to false.
local BurnPID to pidLoop().

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
    CaptureOrbitMFD["DisplayBody"](ship:orbit:NextPatch:body:name).
    SetMFDRefreshTrigger().
    WaitForSOI().
    FlybyBurn().
    CaptureBurn().
  }

//wait until false.

RemoveLocksAndTriggers().

local function FlybyBurn
  {
// Do a flyby burn to guarantee a safe periapsis at which
// to do the capture burn.
// Notes:
//    - This script uses a nominal "safe" flyby height above the surface or atmosphere
//      of a body. A better value could be calculated to take more advantage of the
//      Oberth Effect.
//    - The encounter may be retrograde, and is treated the same as a prograde encounter.
//      The result will be a retrograde capture orbit.
// Todo:
//    - Treat a retrograde encounter as a special case, and force it into
//      a prograde encounter. 

    local SafePeriapsis to ship:body:atm:height+10000.
    local tset to 0.
    local NormalVec to vcrs(ship:position-ship:body:position,ship:velocity:orbit).
    local RadialOutVec to vcrs(ship:velocity:orbit,NormalVec).

    CaptureOrbitMFD["DisplayFlightstatus"]("Fby burn wait").

    set BurnStartTimeUT to time+SteeringDuration.
    lock steering to RadialOutVec.
    until time > BurnStartTimeUT
      wait 0.

    CaptureOrbitMFD["DisplayFlightstatus"]("Flyby burn").

    BurnPID:reset.
    set BurnPID:KP to 1/10000.
    set BurnPID:KI to 0.
    set BurnPID:KD to 0.
    set BurnPID:epsilon to 0.01.
    set BurnPID:setpoint to SafePeriapsis.
    set BurnPID:minoutput to 0.
    set BurnPID:maxoutput to 1.
    set tset to BurnPID:update(time:seconds,ship:orbit:periapsis).
    lock throttle to tset.
    until tset = 0 
      {
        set tset to BurnPID:update(time:seconds,ship:orbit:periapsis).
        wait 0.
      }
    unlock throttle.
  }

local function WaitForSOI
  {
// Wait for the encounter with the body's SOI.
// Notes:
//    - Stop the warp just before the SOI transition - it looks better
//      and you can see the MDF changes OK.
//    - An UNTIL loop is used instead of WAIT to avoid the weird problems
//      when you wait and timewarp at the same time.
// Todo:
//    - Relying on the time of the SOI transition may be
//      unreliable.

    local WarpTimeEndEarly to 10.
    local SOITransitionUT to time+ETA:transition.
    CaptureOrbitMFD["DisplayFlightstatus"]("Wait for SOI").
    if WarpType <> "NOWARP"
      {
        wait 1.
        WarpToTime(SOITransitionUT:seconds-WarpTimeEndEarly,WarpType).
      }
    until time > SOITransitionUT
      wait 0.
// Wait until the next physics tick in case SOI info not updated yet.
    wait 0.
    set SOITransitionDone to true.
  }

local function CaptureBurn
  {
// Do a burn to capture the vessel in a circular orbit around the body.
// Notes:
//    - The capture burn is a retro-burn at periapsis.
//    - The circularization is not very precise, it does not
//      have to be. An eccentricty around 0.1 is OK.
// Todo:
//		- Consider if the capture burn SHOULD be precise.
	
    local ManeuverPointUT to time+eta:periapsis.
    local PeVelocityVec to velocityat(ship,ManeuverPointUT):orbit.
		local deltav to 
      abs(PeVelocityVec:mag-sqrt(ship:body:mu/(ship:body:radius+ship:obt:periapsis))).
    local BurnDuration to
      abs(DeltavEstBurnTime
        (
          deltav,
          ship:mass,
          ship:availablethrust,
          ISPVesselStage()
        )).
    set BurnStartTimeUT to ManeuverPointUT-BurnDuration/2.
    CaptureOrbitMFD["DisplayManuever"](BurnDuration,deltav).
    CaptureOrbitMFD["DisplayFlightstatus"]("Capture wait").
    if WarpType <> "NOWARP"
      {
        wait 1.
        WarpToTime(BurnStartTimeUT:seconds-SteeringDuration,WarpType).
      }
    until time > BurnStartTimeUT-SteeringDuration
      wait 0.
// Calculate the periapsis velocity vector again in case the KSP engine has
// fiddled the axes for some reason. 
    set PeVelocityVec to velocityat(ship,ManeuverPointUT):orbit.
    lock Steering to lookdirup(-PeVelocityVec,ship:facing:topvector).
    until time > BurnStartTimeUT
      wait 0.
    CaptureOrbitMFD["DisplayFlightStatus"]("Capture burn").
    
    CloseHyperbolicOrbit().
    CircularizeOrbit().

	 	CaptureOrbitMFD["DisplayFlightStatus"]("Capture fin").
	}

local function CloseHyperbolicOrbit
  {
// Do a burn to close a hyperbolic orbit into an elliptical orbit.
// Notes:
//    - The point is to get the semi-major axis (SMA) value to something we can use.
//    - The orbit can be an ellipse and still be an "escape" orbit, it only
//      escapes the SOI.
// Todo:
//    -
    local TargetEccentricity to 0.5.
    local tset to 0.
    BurnPID:reset.
    set BurnPID:KP to 5.
    set BurnPID:KI to 0.
    set BurnPID:KD to 0.
    set BurnPID:epsilon to 0.01.
    set BurnPID:setpoint to TargetEccentricity.
    set BurnPID:minoutput to -1.
    set BurnPID:maxoutput to 0.
    set tset to -BurnPID:update(time:seconds,ship:orbit:eccentricity).
    log "Time " + time:seconds + " Input " + ship:orbit:eccentricity + " Output " + tset to log4.txt.
    lock throttle to tset.
    until tset = 0
      {
        set tset to -BurnPID:update(time:seconds,ship:orbit:eccentricity).
        wait 0.
      }
		set tset to 0.
  }

local function CircularizeOrbit
  {
// Do a burn to circularize the orbit.
// Notes:
//    -
// Todo:
//    -
    local tset to 0.
    BurnPID:reset.
    set BurnPID:KP to 1/10000.
    set BurnPID:KI to 0.
    set BurnPID:KD to 0.
    set BurnPID:epsilon to 0.01.
    set BurnPID:setpoint to ship:body:radius+ship:obt:periapsis.
    set BurnPID:minoutput to -1.
    set BurnPID:maxoutput to 0.
    set tset to -BurnPID:update(time:seconds,ship:orbit:semimajoraxis).
    lock throttle to tset.
    until tset = 0
      {
        set tset to -BurnPID:update(time:seconds,ship:orbit:semimajoraxis).
        wait 0.
      }
		set tset to 0.
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
    CaptureOrbitMFD["DisplayLabels"](ship:name).
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
    local TimeToSOI to 0.
    when NextMFDRefreshTime < time:seconds
    then
      {
        if SOITransitionDone
          set TimeToSOI to 0.
        else
          set TimeToSOI to ETA:transition.
        CaptureOrbitMFD["DisplayRefresh"]
         (
          ship:apoapsis,
          ship:periapsis,
          TimeToSOI,
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
//    - I picked "reasonable" values to check for.
// Todo:
//    - Add check for target vessel does not exist.
//    - Test the tolerance of the checks ie run tests to calibrate
//      the values.

    if ship:orbit:transition <> "ENCOUNTER"
      {
        CaptureOrbitMFD["DisplayError"]("This orbit has no SOI encounter").
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
  wait 0.
}