// Name: Escape SOI From Orbit
// Author: JitteryJet
// Version: V01
// kOS Version: 1.3.2.0
// KSP Version: 1.11.2
// Description:
//    Escape the current Sphere Of Influence (SOI) from orbit.
//
// Assumptions:
//    - The plane of the orbit is coplaner with the plane of the SOI
//      ie the vessel is in a equatorial orbit around the
//      body it is escaping from.
//    - The orbit is close to being circular and prograde.
//
// Notes:
//    - The idea is the maneuver causes the vessel to escape the SOI
//      while also lowering it's orbit in the parent SOI. Reasons for doing
//      it this way:
//      - Slowing the vessel down while escaping helps drop the vessel towards the parent body.
//      - Scott Manley said so.
//
// Todo:
//    - Test with planets.
//    - Consider if it makes sense to have the option
//      of escaping inwards or outwards relative to the parent body.
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
runOncePath("MiscFunctions V02").
runoncepath("EscapeSOIFromOrbitMFD V01").
runOncePath("OrbitFunctions V02").
runOncePath("Delta-vFunctions V02").

local NextMFDRefreshTime to time:seconds.
local BurnStartTimeUT to time(0).
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
    EscapeSOIFromOrbitMFD["DisplayFlightStatus"]("Orbiting").
    SetMFDRefreshTrigger().
    EscapeManeuver().
    if WarpType <> "NOWARP"
      {
        wait 1.
        WarpToTime(time():seconds+ETA:transition,WarpType).
      }
    until ship:orbit:transition <> "ESCAPE"
      wait 0.
    EscapeSOIFromOrbitMFD["DisplayFlightStatus"]("Escaped").
  }

//wait until false.

RemoveLocksAndTriggers().

local function EscapeManeuver
  {
// Do an escape maneuver.
// Notes:
//    - Use an ejection angle of 0 degrees - this should be good
//      enough ?
//    - The escape (I think) can be done in at least two ways:
//      - Escape beyond the edge of the SOI only.
//      - Escape to "infinity" using the escape velocity delta-v calculation
//        somehow - I have no idea what this equation looks like.
// Todo:
//    - Allow for not enough time before maneuver point is reached case.
//    - Test prograde and retrograde orbits.

    local ManeuverTrueAnomaly to CalcEjectionTrueAnomaly().

    local ManeuverPositionUT to
      time() +
      TimeToOrbitPosition
        (
          ship:orbit:trueanomaly,
          ManeuverTrueAnomaly,
          ship:orbit:eccentricity,
          ship:orbit:period
        ).
// The square root of 2 calculation is to provide a rough estimate of the
// delta-v only to allow the start time of the burn to be calculated.
    local BurnDeltav to ship:velocity:orbit:mag*sqrt(2)-ship:velocity:orbit:mag.
    local BurnDuration to
      abs(DeltavEstBurnTime
        (
          BurnDeltav,
          ship:mass,
          ship:availablethrust,
          ISPVesselStage()
        )).

    EscapeSOIFromOrbitMFD["DisplayManeuver"](BurnDuration,BurnDeltav).

    set BurnStartTimeUT to ManeuverPositionUT-BurnDuration/2.

    EscapeSOIFromOrbitMFD["DisplayFlightStatus"]("Burn wait").

    if WarpType <> "NOWARP"
      {
        WarpToTime(BurnStartTimeUT:seconds-SteeringDuration,WarpType).
      }

    until time() > BurnStartTimeUT-SteeringDuration
      wait 0.

    EscapeSOIFromOrbitMFD["DisplayFlightStatus"]("Steering wait").

    local SteeringVec to velocityat(ship,ManeuverPositionUT):orbit.
    lock steering to lookDirUp(SteeringVec,ship:facing:topvector).

    until time() > BurnStartTimeUT
      wait 0.

    EscapeSOIFromOrbitMFD["DisplayFlightStatus"]("Escape burn").
    lock throttle to 1.

    wait until ship:orbit:transition = "ESCAPE".

    EscapeSOIFromOrbitMFD["DisplayFlightStatus"]("Escaping").
    lock throttle to 0.

    set BurnStartTimeUT to time(0).

  }

local function CalcEjectionTrueAnomaly
  {
// Calculate the point in the orbit where the "ejection angle" is 180 degrees.
// Notes:
//    - This calculation is a bit overcooked to allow for the 
//      orbit to be a little inclined and a little eccentric?
// Todo:
//    - Test slighly inclined and slightly eccentric orbits.
//    - Test prograde and retrograde orbits.

    local SOIRawPositionVec to ship:orbit:position-ship:body:position.
    local EjectionVec to -ship:body:body:velocity:orbit.
    local OrbitNormalVec to vcrs(SOIRawPositionVec,ship:velocity:orbit).
    local EccentricityVec to
      CalcEccentricityVec(SOIRawPositionVec,ship:velocity:orbit,ship:body:mu).

    local EjectionTrueAnomaly to
      CalcTrueAnomalyFromVec(EjectionVec,EccentricityVec,OrbitNormalVec).

    return EjectionTrueAnomaly.
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
    EscapeSOIFromOrbitMFD["DisplayLabels"](ship:name).
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
        EscapeSOIFromOrbitMFD["DisplayRefresh"]
         (
          ship:apoapsis,
          ship:periapsis,
          ship:body:name,
          BurnStartTimeUT:seconds,
          time():seconds
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

    if ship:status <> "ORBITING"
      EscapeSOIFromOrbitMFD["DisplayError"]("This vessel is not orbiting").

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