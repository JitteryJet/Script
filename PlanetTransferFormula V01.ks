// Name: PlanetTransferFormula
// Author: JitteryJet
// Version: V01
// kOS Version: 1.3.2.0
// KSP Version: 1.12.3
// Description:
//    Transfer the vessel in a parking orbit around a planet
//    to another planet using formulas.
//
// Assumptions:
//    - All orbits are prograde (anticlockwise) defined
//      by north being up. All orbits are near-circular
//      and near-coplanar.
//      This program MIGHT work with other combinations
//      but is untested. 
//    - 
//
// Notes:
//    - This script calculates a trajectory using the Patched Conic Formula method.
//      The vessel will follow the trajectory as calculated by the formulas,
//      no correction burns are done.
//    - The Patched Conic method breaks the trajectory down into segments
//      which are "patched" together (hence the name).
//      These types of transfers are handled:
//      Transfer from a planet to another:
//        1.  Hyperbolic escape from a parking orbit around the departure
//            planet.
//        2.  Elliptical orbit to the arrival planet.
//        3.  Hyperbolic capture or a flyby at the arrival planet.
//      Transfer from a planet to a vessel:
//        1.  Hyperbolic escape from a parking orbit around the departure
//            planet.
//        2.  Elliptical orbit to another vessel.
//        3.  Flyby of the arrival vessel.
//      Transfer from a moon to another moon in the same planetary system:
//        1.  Hyperbolic escape from a parking orbit around the departure
//            moon.
//        2.  Elliptical orbit to the arrival moon.
//        3.  Hyperbolic capture or a flyby at the arrival moon.
//      Transfer from a moon to a vessel in the same planetary system:
//        1.  Hyperbolic escape from a parking orbit around the departure
//            moon.
//        2.  Elliptical orbit to another vessel.
//        3.  Flyby of the arrival vessel.
//    -         
//
// Todo:
//    - Add check to ensure there is enough time
//      to steer and burn before reaching the maneuver point.
//    - Think about error conditions such as target name not found etc.
//    - Add error checking to ensure the departure and arrival
//      orbital combinations are valid.
//
// Update History:
//    26/12/2021 V01  - Created.
//                    -
//
@lazyglobal off.
// Parameter descriptions.        
//    OrbitalName             Name of the target orbital.
//    EncounterType           Type of encounter "CAPTURE" or "FLYBY".
//                            at the target planet or moon (km).
//                            For a flyby set to zero.   
//    SteeringDuration        Time to allow the vessel to steer to the burn
//                            attitude for the maneuver (s).                            
//	  WarpType	  					  "PHYSICS","RAILS" or "NOWARP".

parameter OrbitalName to "".
parameter EncounterType to "CAPTURE".
parameter SteeringDuration to 60.
parameter WarpType to "NOWARP".

// Load in library functions.
runoncepath("PlanetTransferFormulaMFD V01").
runoncepath("Delta-vFunctions V03").
runoncepath("OrbitFunctions V03").
runoncepath("MiscFunctions V04").

local NextMFDRefreshTime to time:seconds.
local ArrivalOrbital to 0.
local PhasingAngle to 0.
local EjectionAngle to 0.
local BurnStartTimeUT to time(0).
local FatalError to false.
local MFDRefreshTriggerActive to true.
local StagingTriggerActive to true.
local lock ShipPositionVec to ship:position-ship:body:position.
local lock ShipObtNormalVec to vcrs(ShipPositionVec,ship:velocity:obt).
// Use the mean orbit radius in calculations.
local DepartureObtRadius to (ship:body:obt:apoapsis+ship:body:obt:periapsis)/2+ship:body:body:radius.
local ArrivalObtRadius to 0.

sas off.
set ship:control:mainthrottle to 0.
if WarpType <> "NOWARP"
  set kuniverse:timewarp:mode to WarpType. 
lock throttle to 0.
clearvecdraws().
SetStagingTrigger().
GetArrivalOrbital().
SetMFD().
CheckForErrorsAndWarnings().
if not FatalError
  {
    WaitForAlignment().
    EscapeFromDeparture().
//    WaitForTransfer().
    if bodyExists(OrbitalName)
      {
        if EncounterType = "CAPTURE"
          CaptureAtArrival().
        else
        if EncounterType = "FLYBY"
          FlybyAtArrival().
      }
  }
RemoveLocksAndTriggers().

local function WaitForAlignment
  {
// Wait for the alignment between the departure body
// and the arrival orbital.
// Notes:
//    - 
// Todo:
//    - This function contains some "clever code" to handle the
//      different alignment cases. It might make more sense to
//      code the different cases more explicitly.
//    - 

    local AngleToManeuverPoint to 0.
    local RelativeAngle to 0.
    local AngularSpeed to 0.
    local WaitDuration to 0.

    set RelativeAngle to CalcRelativeAngle().
    set PhasingAngle to
      constant:pi*(1-((DepartureObtRadius+ArrivalObtRadius)/(2*ArrivalObtRadius))^1.5)
        *constant:RadToDeg.
    set AngularSpeed to 360/ArrivalOrbital:obt:period-360/ship:body:obt:period.

    set AngleToManeuverPoint to RelativeAngle-PhasingAngle.
    
    if AngleToManeuverPoint < 0 and AngularSpeed < 0
      set AngleToManeuverPoint to AngleToManeuverPoint+360.

    if AngleToManeuverPoint > 0 and AngularSpeed > 0
      set AngleToManeuverPoint to AngleToManeuverPoint-360.

    set WaitDuration to abs(AngleToManeuverPoint/AngularSpeed).

    PlanetTransferMFD["DisplayFlightStatus"]("Alignment wait").
    if WarpType = "NOWARP"
      wait WaitDuration.
    else
      {
        kuniverse:timewarp:warpTo(time:seconds+WaitDuration).
        wait WaitDuration.
      }
  }

local function EscapeFromDeparture
  {
// Escape from the departure body.
// Notes:
//    - Escape from the body and SOI by using a
//      hyperbolic escape maneuver from the parking orbit that results in
//      a hyperbolic excess speed (v infinity) sufficient to get to
//      the arrival via an elliptical orbit.
//    - Lots of orbits to keep track of:
//        ParkingObt - Parking orbit where the burn is done.
//        DepartureObt - Orbit of the planet/moon departed from.
//        EscapeObt - Hyperbolic escape orbit after the burn.
//        EllipticalObt - Elliptical transfer orbit from the
//                        departure planet/moon SOI to the arrival
//                        planet/moon SOI.
//    -     
// Todo:
//    - Handle situation where there is not enough time for the burn
//      instead of raising a fatal error.
//    -

    local ParkingObtv to 0.
    local ParkingObtRadius to 0.
    local DepartureObtv to 0.
    local EscapeObtv to 0.
    local EscapeObtSMA to 0.
    local EscapeObtEcc to 0.
    local EllipticalObtv to 0.
    local EllipticalObtSMA to 0.
    local vInfinity to 0.
    local BurnDeltav to 0.
    local BurnVec to 0.
    local BurnDuration to 0.
    local ManeuverPointUT to 0.
    locaL AngleToHeadingPoint to 0.
    local AngleToManeuverPoint to 0.
    local SteeringDir to 0.
    local TimeToSOITransition to 0.

    set DepartureObtv to ship:body:obt:velocity:obt:mag.
    set ParkingObtRadius to ship:altitude+ship:body:radius.
    set ParkingObtv to ship:obt:velocity:orbit:mag.
    set EllipticalObtSMA to (DepartureObtRadius+ArrivalObtRadius)/2.

    set EllipticalObtv to
      sqrt(ship:body:body:mu*(2/DepartureObtRadius-1/EllipticalObtSMA)).
    set vInfinity to EllipticalObtv-DepartureObtv.
    set EscapeObtSMA to -ship:body:mu/vInfinity^2.
    set EscapeObtv to
      sqrt(ship:body:mu*(2/ParkingObtRadius-1/EscapeObtSMA)).
    set BurnDeltav to EscapeObtv-ParkingObtv.

// Escape turning angle calculation using my own formula derived from other
// formula. It is the angle the trajectory of the vessel is turned
// by gravity while escaping to the edge of the SOI.

    set EscapeObtEcc to 1-ParkingObtRadius/EscapeObtSMA.
    set EjectionAngle to arcCos(-1/EscapeObtEcc).

// Calculate the angle between the vessel and the prograde or
// retrograde heading of the planet/moon in it's orbit.
    if ArrivalObtRadius > DepartureObtRadius
      {
// Burn to go from a low orbit to a higher orbit.
        set AngleToHeadingPoint to
          vang(ShipPositionVec,ship:body:obt:velocity:obt).
        if vang(ShipPositionVec,vcrs(ShipObtNormalVec,ship:body:obt:velocity:obt)) < 90
          set AngleToHeadingPoint to 360-AngleToHeadingPoint.
      }
    else
      {
// Burn to go from a high orbit to a lower orbit.
        set AngleToHeadingPoint to
          vang(ShipPositionVec,-ship:body:obt:velocity:obt).
        if vang(ShipPositionVec,vcrs(ShipObtNormalVec,-ship:body:obt:velocity:obt)) < 90
          set AngleToHeadingPoint to 360-AngleToHeadingPoint.
      }

// Not sure how the angles might add up here. Needs testing.
    set AngleToManeuverPoint to mod(AngleToHeadingPoint-EjectionAngle,360).
    if AngleToManeuverPoint < 0
      set AngleToManeuverPoint to AngleToManeuverPoint+360.

    set ManeuverPointUT to
      time+AngleToManeuverPoint*ship:obt:period/360.

    set BurnDuration to
      DeltavEstBurnTime
        (
          BurnDeltav,
          ship:mass,
          ship:availablethrust,
          ISPVesselStage()
        ).
    set BurnStartTimeUT to ManeuverPointUT-BurnDuration/2.
    PlanetTransferMFD["DisplayManuever"](BurnDuration,BurnDeltav).
    PlanetTransferMFD["DisplayFlightStatus"]("Escape Brn Wait").

// Check to see if there is enough time to do the burn,
// stop the program if not.
    if time > (BurnStartTimeUT-SteeringDuration)
      {
        PlanetTransferMFD["DisplayError"]("Not enough time for escape burn").
        print 0/0.
      }

    if WarpType = "NOWARP"
      wait BurnStartTimeUT:seconds-SteeringDuration-time:seconds.
    else
      {
        kuniverse:timewarp:warpTo(BurnStartTimeUT:seconds-SteeringDuration).
        wait BurnStartTimeUT:seconds-SteeringDuration-time:seconds.
      }

    set BurnVec to velocityat(ship,ManeuverPointUT):orbit.
    set SteeringDir to lookdirup(BurnVec,ship:facing:topvector).
    lock steering to SteeringDir.

    PlanetTransferMFD["DisplayFlightStatus"]("Steering wait").
    wait SteeringDuration.

    PlanetTransferMFD["DisplayFlightStatus"]("Escape burn").
    TransferBurn
      (
        BurnVec,
        DepartureObtRadius,
        ArrivalObtRadius
      ).
    set BurnStartTimeUT to time(0).
    PlanetTransferMFD["DisplayFlightStatus"]("Escaping wait").

    set TimeToSOITransition to ship:obt:eta:transition.
    if WarpType = "NOWARP"
      wait TimeToSOITransition.
    else
      {
        kuniverse:timewarp:warpTo(time:seconds+TimeToSOITransition).
        wait TimeToSOITransition.
        wait until kuniverse:timewarp:issettled.
      }
// Ensure that the transition into the transfer SOI is complete.
    wait until ship:obt:transition <> "ESCAPE".
  }

local function WaitForTransfer
  {
// Wait for the transfer orbit to complete.
// Notes:
//    - FYI Last checked 15/12/2021. KSP has a bug where the future ENCOUNTER
//      transition info disappears when timewarping near
//      the transition, it gets set to the following FINAL transition info
//      ie it is like the encounter does not happen. Once the vessel transitions
//      into the encounter SOI, the info is updated correctly.
//    -
// Todo:
//    -

    local TimeToEncounter to 0.

    PlanetTransferMFD["DisplayFlightStatus"]("Transfer wait").
    if bodyExists(OrbitalName)
      set TimeToEncounter to ship:obt:eta:transition.
    else
      set TimeToEncounter to ship:obt:eta:apoapsis.
    if WarpType = "NOWARP"
      wait TimeToEncounter.
    else
      {
        kuniverse:timewarp:warpTo(time:seconds+TimeToEncounter).
        wait TimeToEncounter.
        wait until kuniverse:timewarp:issettled.
        wait 0.
      }

// Ensure that the encounter with the SOI is complete so the ship's
// body-related variables are updated.
    if bodyExists(OrbitalName)
      wait until ship:obt:body:name = OrbitalName.
  }

local function CaptureAtArrival
  {
// Capture at the arrival Sphere of Influence.
// Notes:
//    - The capture burn is done at the periapsis of the hyperbolic
//      orbit at arrival. The capture radius is the periapsis.
//    - The reference frames are counter-intuitive. The arrival
//      body will actually be orbiting FASTER than the vessel
//      at the apoapsis of an elliptical transfer orbit - so
//      the vessel has to SPEED UP to be captured!
//    -
// Todo:
//    - 

    local ManeuverPointUT to 0.
    local Capturev to 0.
    local CaptureRadius to 0.
    local BurnDeltav to 0.
    local BurnDuration to 0.
    local BurnVec to 0.
    local SteeringDir to 0.

    set ManeuverPointUT to time+ship:obt:eta:periapsis.

    set CaptureRadius to ship:obt:periapsis+ship:obt:body:radius.
    set Capturev to sqrt(ship:obt:body:mu/CaptureRadius).
    set BurnDeltav to velocityat(ship,ManeuverPointUT):obt:mag-Capturev.

    set BurnDuration to
      DeltavEstBurnTime
        (
          BurnDeltav,
          ship:mass,
          ship:availablethrust,
          ISPVesselStage()
        ).
    set BurnStartTimeUT to ManeuverPointUT-BurnDuration/2.
    PlanetTransferMFD["DisplayManuever"](BurnDuration,BurnDeltav).
    PlanetTransferMFD["DisplayFlightStatus"]("Capture wait").

// Check to see if there is enough time to do the burn,
// stop the program if not.
    if time > (BurnStartTimeUT-SteeringDuration)
      {
        PlanetTransferMFD["DisplayError"]("Not enough time for capture burn").
        print 0/0.
      }
//    kuniverse:pause().
    if WarpType = "NOWARP"
      wait BurnStartTimeUT:seconds-SteeringDuration-time:seconds.
    else
      {
        kuniverse:timewarp:warpTo(BurnStartTimeUT:seconds-SteeringDuration).
        wait BurnStartTimeUT:seconds-SteeringDuration-time:seconds.
        wait until kuniverse:timewarp:issettled.
      }

    set BurnVec to -velocityat(ship,ManeuverPointUT):obt.
    set SteeringDir to lookdirup(BurnVec,ship:facing:topvector).
    lock steering to SteeringDir.

    PlanetTransferMFD["DisplayFlightStatus"]("Steering wait").
    wait SteeringDuration.

    PlanetTransferMFD["DisplayFlightStatus"]("Capture burn").
    lock throttle to 1.
    wait BurnDuration.
    lock throttle to 0.
    unlock steering.
    PlanetTransferMFD["DisplayFlightStatus"]("Capture brn fin").

  }

local function FlybyAtArrival
  {
// Flyby at the arrival Sphere of Influence.
// Notes:
//    - Do nothing.
// Todo:
//    -
  }

local function TransferBurn
  {
// Transfer burn.
// Notes:
//    - The burn is done in two parts:
//      - Hyperbolic escape burn to reach the edge of depature SOI.
//      - Elliptical transfer burn to reach the arrival orbital.
//    - Strickly speaking this is not a pure "formula" burn as
//      it uses closed loops to finish the burn. 
//    - The burn is throttled down as the apsis nears the arrival orbit
//      altitude to reduce overshoot.
//    - This code is a bit dodgy.
//      The code logic might fail if the trajectory during the burn encounters a moon
//      and it interfers with the test for hyperbolic escape speed (transition="ESCAPE").
//    -
// Todo:
//    - Improve the dodgy hyperbolic escape test code.

    parameter BurnVec.
    parameter DepartureRadius.
    parameter ArrivalRadius.

// Percentage of radius where the throttledown starts.
// Increasing this value may improve the precision of the burn
// at the expense of increasing the burn time.
    local ThrottledownPerc to 20.

// Minimum throttle to give a sort of "deadzone" on the throttle
// ramp down to guarantee the burn loop completes.
    local MinThrottle to 0.01.

    local ThrottledownThreshold to 0.
    local remaining to 0.
    local ThrottleSet to 0.
    lock throttle to Throttleset.
    lock steering to lookDirUp(BurnVec,ship:facing:topvector).

    set ThrottledownThreshold to ArrivalRadius*(ThrottledownPerc/100).

// Burn until the hyperbolic escape velocity is reached.
    set Throttleset to 1.
    wait until ship:obt:transition = "ESCAPE".

// Keep burning until the trajectory reaches the arrival radius.
    if DepartureRadius < ArrivalRadius
      {
        set remaining to ArrivalRadius.
        until remaining <= 0
          {
            if ThrottledownThreshold > 0
              set ThrottleSet to min(1,remaining/ThrottledownThreshold+MinThrottle).
            set remaining to
              ArrivalRadius-(ship:obt:nextpatch:apoapsis+ship:obt:nextpatch:body:radius).
            wait 0.
          }
      }
    else
      {
        set remaining to DepartureRadius.
        until remaining <= 0
          {
            if ThrottledownThreshold > 0
              set ThrottleSet to min(1,remaining/ThrottledownThreshold+MinThrottle).
            set remaining to (ship:obt:nextpatch:periapsis+ship:obt:nextpatch:body:radius)-ArrivalRadius.
            wait 0.
          }
      }
    set ThrottleSet to 0.
    unlock throttle.
    unlock steering.
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
    set terminal:height to 21.
    PlanetTransferMFD["DisplayLabels"]
      (ship:name,OrbitalName).
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
        PlanetTransferMFD["DisplayRefresh"]
         (
          ship:obt:apoapsis,
          ship:obt:periapsis,
          ship:obt:eccentricity,
          CalcRelativeAngle(),
          PhasingAngle,
          EjectionAngle,
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

local function GetArrivalOrbital
  {
// Get the arrival orbital.
// Notes:
//    - If the name of the orbit is incorrect the
//      script will stop with an error at this point.
// Todo:
//    -
    if bodyExists(OrbitalName)
      {
        set ArrivalOrbital to body(OrbitalName).
      }
    else
      {
        set ArrivalOrbital to vessel(OrbitalName).         
      }

// Use the mean orbit radius in calculations as the arrival orbit may not be exactly circular.
    set ArrivalObtRadius to
      (ArrivalOrbital:obt:apoapsis+ArrivalOrbital:obt:periapsis)/2+ArrivalOrbital:body:radius.
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
//    - Add the missing tests.
//    -

    if EncounterType <> "CAPTURE"
      and EncounterType <> "FLYBY"
      {
        PlanetTransferMFD["DisplayError"]("Encounter type is unknown").
        set FatalError to true.
      }
    else
    if EncounterType = "CAPTURE"
      and not bodyExists(OrbitalName)
      {
        PlanetTransferMFD["DisplayError"]("Capture only valid for planet or moon").
        set FatalError to true.
      }
    else
    if OrbitalName = ship:ShipName
      {
        PlanetTransferMFD["DisplayError"]("Target orbital name same as this vessel").
        set FatalError to true.
      }
    else
    if ship:orbit:eccentricity >= 0.01
      PlanetTransferMFD["DisplayError"]("Parking orbit is not circular").
    else
    if ArrivalOrbital:obt:eccentricity >= 0.01
      PlanetTransferMFD["DisplayError"]("Arrival orbit is not circular").
    else
    if CalcRelativeInclination
        (
          vcrs(ship:body:obt:position-ship:body:body:position,ship:body:obt:velocity:orbit),
          vcrs(ArrivalOrbital:obt:position-ArrivalOrbital:body:position,ArrivalOrbital:obt:velocity:orbit)
        ) > 0.5
      PlanetTransferMFD["DisplayError"]("Arrival orbit is inclined to departure orbit").
  }

local function CalcRelativeAngle
  {
// Calculate the relative angle between departure planet and the target orbital.
// Notes:
//    -
// Todo:
//    -

    local angle to 0.
    if ship:body:name = "Sun" return 0.
    set angle to
      (
        ArrivalOrbital:obt:longitudeofascendingnode
          +ArrivalOrbital:obt:argumentofperiapsis
          +ArrivalOrbital:obt:trueanomaly
      )
      -
        (
          ship:body:obt:longitudeofascendingnode
            +ship:body:obt:argumentofperiapsis
            +ship:body:obt:trueanomaly
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