// Name: HohmannTransfer
// Author: JitteryJet
// Version: V02
// kOS Version: 1.3.2.0
// KSP Version: 1.12.1
// Description:
//    Transfer the vessel from one orbit to another by using a
//    Hohmann transfer. 
//
// Assumptions:
//    - The vessel and a target orbital both
//      travel in prograde (anticlockwise) direction
//      defined by north being up. This program MIGHT
//      work with other combinations but I didn't code
//      or test for it.
//    - An accurate transfer relies on the departure and
//      arrival orbits being as circular as possible and
//      as coplaner as possible.
//    - The vessel and target orbital are in the same SOI.
//
// Notes:
//    - No second burn is done if the target is a body
//      or the first burn results in an escape orbit.
//    - A transfer to a body will usually result in an
//      encounter; however an encounter is not guaranteed.      
//
// Todo:
//    - Add the throttledown percentage as a program parameter.
//    - Add check to ensure there is enough time
//      to steer and burn before reaching the maneuver point.
//    - Do not allow targets in a different SOI to be selected.
//
// Update History:
//    28/03/2021 V01  - Created.
//    10/08/2021 V02  - Added the transfer angles to the MFD.
//                    - Added eccentricity to the MFD.
//                    - Removed the PID loops.
//
@lazyglobal off.
// Parameter descriptions.        
//	  OrbitAltkm  				    Sea level altitude of the final orbit (km)
//                            if not matching a target orbit. 
//    OrbitalName             Name of a target orbital to match orbits with.
//    SteeringDuration        Time to allow the vessel to steer to the burn
//                            attitude for the maneuver (s).                            
//	  WarpType	  					  "PHYSICS","RAILS" or "NOWARP".

parameter OrbitAltkm to 500.
parameter OrbitalName to "".
parameter SteeringDuration to 60.
parameter WarpType to "NOWARP".

// Load in library functions.
runoncepath("HohmannTransferMFD V02").
runoncepath("Delta-vFunctions V03").
runoncepath("OrbitFunctions V03").
runoncepath("MiscFunctions V04").

local OrbitAltitude is OrbitAltkm*1000.
local NextMFDRefreshTime to time:seconds.
local TargetOrbital to 0.
local TransferAngle to 0.
local BurnStartTimeUT to time(0).
local FatalError to false.
local MFDRefreshTriggerActive to true.
local StagingTriggerActive to true.
local DepartureRadius to 0.
local ArrivalRadius to 0.

// Other initialisations.
sas off.
set ship:control:mainthrottle to 0.
lock throttle to 0.
clearvecdraws().
SetStagingTrigger().
if OrbitalName <> ""
  GetTargetOrbital().
SetMFD().
CheckForErrorsAndWarnings().
if not FatalError
  {
    if OrbitalName = ""
      {
        Transfer().
        if ship:orbit:transition = "FINAL"
          Circularization().
      }
    else
      {
        MatchOrbitTransfer().
        if not bodyExists(OrbitalName)
          and ship:orbit:transition = "FINAL"
          Circularization().
      }
    
  }
// Short wait to allow the MFD to catch up.
wait 1.
RemoveLocksAndTriggers().

local function Transfer
  {
// Do the transfer.
// Notes:
//    - Transfer from a lower orbit to a
//      higher orbit and vice versa.
//    - The burn can be done anywhere in the
//      departure orbit.
//    -
// Todo:
//    -

    local BurnVec to 0.
    local ManeuverPointUT to 0.

    set DepartureRadius to (ship:apoapsis+ship:periapsis)/2+ship:body:radius.
    set ArrivalRadius to OrbitAltitude+ship:body:radius.

    local BurnDeltav to CalcHohmannTransferDeltav(DepartureRadius,ArrivalRadius,ship:body:mu).

    local BurnDuration to
      abs(DeltavEstBurnTime
        (
          BurnDeltav,
          ship:mass,
          ship:availablethrust,
          ISPVesselStage()
        )).

    HohmannTransferMFD["DisplayManuever"](BurnDuration,abs(BurnDeltav)).

    set ManeuverPointUT to time+SteeringDuration+BurnDuration/2.
    set BurnStartTimeUT to time+SteeringDuration.

    if DepartureRadius < ArrivalRadius
      set BurnVec to velocityat(ship,ManeuverPointUT):orbit.
    else
      set BurnVec to -velocityat(ship,ManeuverPointUT):orbit.

    local SteeringDir to lookdirup(BurnVec,ship:facing:topvector).

    HohmannTransferMFD["DisplayFlightStatus"]("Steering wait").

    lock steering to SteeringDir.
    wait SteeringDuration.
    
    HohmannTransferMFD["DisplayFlightStatus"]("Transfer burn").

    TransferBurn
      (
        BurnVec,
        DepartureRadius,
        ArrivalRadius
      ).
    HohmannTransferMFD["DisplayFlightStatus"]("Trans burn fin").
  }

local function Circularization
  {
// Do the circularization.
// Notes:
//    -
// Todo:
//    -

    local SteeringDir to 0.
    local BurnDeltav to 0.
    local BurnVec to 0.
    local ManeuverPointUT to 0.

    set BurnDeltav to CalcHohmannCircularizationDeltav(DepartureRadius,ArrivalRadius,ship:body:mu).

    local BurnDuration to
      abs(DeltavEstBurnTime
        (
          BurnDeltav,
          ship:mass,
          ship:availablethrust,
          ISPVesselStage()
        )).

    HohmannTransferMFD["DisplayManuever"](BurnDuration,abs(BurnDeltav)).

    if DepartureRadius < ArrivalRadius
      {
        set ManeuverPointUT to time+eta:apoapsis.
        set BurnVec to velocityat(ship,ManeuverPointUT):orbit.
      }
    else
      {
        set ManeuverPointUT to time+eta:periapsis.
        set BurnVec to -velocityat(ship,ManeuverPointUT):orbit.
      }
    set BurnStartTimeUT to ManeuverPointUT-BurnDuration/2.

    HohmannTransferMFD["DisplayFlightStatus"]("Circ burn wait").

    if WarpType <> "NOWARP"
      {
        wait 1. // Wait to allow acceleration to settle etc.
        WarpToTime(BurnStartTimeUT:seconds-SteeringDuration,WarpType).
      }
    wait BurnStartTimeUT:seconds-SteeringDuration-time:seconds.
    wait until kuniverse:timewarp:issettled.

    set SteeringDir to lookdirup(BurnVec,ship:facing:topvector).

    HohmannTransferMFD["DisplayFlightStatus"]("Steering wait").

    lock steering to SteeringDir.
    until time > BurnStartTimeUT
      wait 0.

    HohmannTransferMFD["DisplayFlightStatus"]("Circ burn").

    CircularizationBurn
      (
        BurnVec,
        DepartureRadius,
        ArrivalRadius
      ).
    HohmannTransferMFD["DisplayFlightStatus"]("Circ burn fin").
  }

local function MatchOrbitTransfer
  {
// Do the transfer to match orbits with
// another orbital. 
// Notes:
//    - 
// Todo:
//    - Test to see if this solution works with orbits that are almost
//      identical.
//    - Retest for a non-body orbital ie a vessel or asteroid.
//    -

    local AngleToManeuverPoint to 0.
    local BurnDeltav to 0.
    local BurnVec to 0.
    local BurnDuration to 0.
    local SteeringDir to 0.
    local RelativeAngle to CalcRelativeAngle().

// Set the departure and arrival orbit heights to "idealized"
// values to calculate a estimate of the Hohmann transfer angle.

    set DepartureRadius to (ship:apoapsis+ship:periapsis)/2+ship:body:radius.
    set ArrivalRadius to (TargetOrbital:apoapsis+TargetOrbital:periapsis)/2+ship:body:radius.
    set TransferAngle to CalcHohmannOrbitAngle(DepartureRadius,ArrivalRadius).
    set BurnDeltav to
      CalcHohmannTransferDeltav(DepartureRadius,ArrivalRadius,ship:body:mu).
    set BurnDuration to
      DeltavEstBurnTime
        (
          abs(BurnDeltav),
          ship:mass,
          ship:availablethrust,
          ISPVesselStage()
        ).

    if DepartureRadius < ArrivalRadius
      {
        set AngleToManeuverPoint to RelativeAngle-TransferAngle.      
      }
    else
      {
        set AngleToManeuverPoint to TransferAngle-RelativeAngle.
      }
    set AngleToManeuverPoint to mod(AngleToManeuverPoint,360).
    if AngleToManeuverPoint < 0
      set AngleToManeuverPoint to AngleToManeuverPoint+360.

    local TimeToManeuverPoint to AngleToManeuverPoint/(360*abs(1/ship:orbit:period-1/TargetOrbital:orbit:period)).
    local ManeuverPointUT to time()+TimeToManeuverPoint.

    set BurnStartTimeUT to ManeuverPointUT-BurnDuration/2.

    HohmannTransferMFD["DisplayFlightStatus"]("Trans burn wait").
    HohmannTransferMFD["DisplayManuever"](BurnDuration,abs(BurnDeltav)).

    if WarpType <> "NOWARP"
      {
        WarpToTime(BurnStartTimeUT:seconds-SteeringDuration,WarpType).
      }
    wait BurnStartTimeUT:seconds-SteeringDuration-time:seconds.
    wait until kuniverse:timewarp:issettled.

    if DepartureRadius < ArrivalRadius
      set BurnVec to velocityat(ship,ManeuverPointUT):orbit.
    else
      set BurnVec to -velocityat(ship,ManeuverPointUT):orbit.

    set SteeringDir to lookdirup(BurnVec,ship:facing:topvector).
    lock steering to SteeringDir.
    HohmannTransferMFD["DisplayFlightStatus"]("Steering wait").
    wait SteeringDuration.

    HohmannTransferMFD["DisplayFlightStatus"]("Transfer burn").
    TransferBurn
      (
        BurnVec,
        DepartureRadius,
        ArrivalRadius
      ).
    HohmannTransferMFD["DisplayFlightStatus"]("Trans burn fin").
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
    if OrbitalName = ""
      HohmannTransferMFD["DisplayLabels"]
        (ship:name,OrbitAltitude,"").
    else
      HohmannTransferMFD["DisplayLabels"]
        (ship:name,0,OrbitalName).
    SetMFDRefreshTrigger().
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
    when (NextMFDRefreshTime < time:seconds)
    then
      {
        HohmannTransferMFD["DisplayRefresh"]
         (
          ship:apoapsis,
          ship:periapsis,
          ship:orbit:eccentricity,
          CalcRelativeAngle(),
          TransferAngle,
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

local function GetTargetOrbital
  {
// Get the target orbital.
// Notes:
//    -
// Todo:
//    -
    if bodyExists(OrbitalName)
      {
        set TargetOrbital to body(OrbitalName).
      }
    else
      {
        set TargetOrbital to vessel(OrbitalName).         
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

    if OrbitalName = ship:ShipName
      {
        HohmannTransferMFD["DisplayError"]("Target orbital name same as this vessel").
        set FatalError to true.
      }
    else
    if ship:orbit:eccentricity >= 0.01
      HohmannTransferMFD["DisplayError"]("This orbit is not circular").
    else
    if OrbitalName <> "" and TargetOrbital:orbit:eccentricity >= 0.01
      HohmannTransferMFD["DisplayError"]("Target orbit is not circular").
    else
    if OrbitalName <> ""
      and CalcRelativeInclination
            (
              vcrs(ship:orbit:position-ship:body:position,ship:orbit:velocity:orbit),
              vcrs(TargetOrbital:orbit:position-TargetOrbital:body:position,TargetOrbital:orbit:velocity:orbit)
            ) > 0.5
      HohmannTransferMFD["DisplayError"]("This orbit is inclined to target orbit").
  }

local function CalcRelativeAngle
  {
// Calculate the relative angle between vessel and a target orbital.
// Notes:
//    -
// Todo:
//    -

    if TargetOrbital = 0
      return 0.
    local angle is
      (
        TargetOrbital:orbit:longitudeofascendingnode+
        TargetOrbital:orbit:argumentofperiapsis+
        TargetOrbital:orbit:trueanomaly
      )
      -
        (
          ship:orbit:longitudeofascendingnode+
          ship:orbit:argumentofperiapsis+
          ship:orbit:trueanomaly
        ).
    set angle to mod(angle,360).
    if angle < 0
      set angle to angle+360.
    return angle. 
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

local function TransferBurn
  {
// Hohmann Transfer burn.
// Notes:
//    - Closed loop (feedback) control.
//    - The burn is throttled down as the apsis nears the target orbit
//      altitude to increase the precision of the maneuver.
// Todo:
//    -

    parameter BurnVec.
    parameter DepartureRadius.
    parameter ArrivalRadius.

// Percentage of radius where the control-throttledown starts.
// Increasing this value may improve the precision of the burn
// at the expense of throttling down a bit longer.
    local ThrottledownPerc to 20.

    local ThrottledownAlt to 0.
    local error to 0.
    local ThrottleSet to 0.
    lock throttle to Throttleset.
    lock steering to lookDirUp(BurnVec,ship:facing:topvector).
    if DepartureRadius < ArrivalRadius
      {
        set ThrottledownAlt to ArrivalRadius*(ThrottledownPerc/100).
        until ship:apoapsis+ship:body:radius >= ArrivalRadius
          {
            set error to ArrivalRadius-(ship:apoapsis+ship:body:radius).
            set ThrottleSet to min(1,error/ThrottledownAlt+0.01).
            wait 0.
          }
      }
    else
      {
        set ThrottledownAlt to (ship:periapsis+ship:body:radius)*(ThrottledownPerc/100).
        until ship:periapsis+ship:body:radius <= ArrivalRadius
          {
            set error to (ship:periapsis+ship:body:radius)-ArrivalRadius.
            set ThrottleSet to min(1,error/ThrottledownAlt+0.01).
            wait 0.
          }
      }
    set ThrottleSet to 0.
    unlock throttle.
    unlock steering.
  }

local function CircularizationBurn
  {
// Hohman Transfer circularization burn.
// Notes:
//    - Closed loop (feedback) control.
//    - The burn is throttled down as the apsis nears the circularization
//      altitude to increase the precision of the maneuver.
// Todo:
//    -

    parameter BurnVec.
    parameter DepartureRadius.
    parameter ArrivalRadius.

// Percentage of radius where the control-throttledown starts.
// Increasing this value may improve the precision of the burn
// at the expense of throttling down a bit longer.
    local ThrottledownPerc to 20.

    local ThrottledownAlt to 0.
    local error to 0.
    local ThrottleSet to 0.
    local PrevEcc to 9999.
    lock throttle to Throttleset.
    lock steering to lookDirUp(BurnVec,ship:facing:topvector).
    set ThrottledownAlt to ArrivalRadius*(ThrottledownPerc/100).
    if DepartureRadius < ArrivalRadius
      {
        until ship:orbit:eccentricity >= PrevEcc
          {
            set PrevEcc to ship:orbit:eccentricity.
            set error to abs(ArrivalRadius-(ship:periapsis+ship:body:radius)).
            set ThrottleSet to min(1,error/ThrottledownAlt+0.01).
            wait 0.
          }
      }
    else
      {
        until ship:orbit:eccentricity >= PrevEcc
          {
            set PrevEcc to ship:orbit:eccentricity.
            set error to abs((ship:apoapsis+ship:body:radius)-ArrivalRadius).
            set ThrottleSet to min(1,error/ThrottledownAlt+0.01).
            wait 0.
          }
      }
    set ThrottleSet to 0.
    unlock throttle.
    unlock steering.
  }

