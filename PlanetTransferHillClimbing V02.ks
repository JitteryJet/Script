// Name: PlanetTransferHillClimbing
// Author: JitteryJet
// Version: V02
// kOS Version: 1.3.2.0
// KSP Version: 1.12.3
// Description:
//    Transfer the ship from a parking orbit to a body or ship
//    orbiting in the same SOI by using a Hill Climbing search.
//
// Assumptions:
//    - All orbits are prograde (anticlockwise) defined
//      by north being up. All orbits are near-circular
//      and near-coplanar.
//    - The departure and arrival orbits do not cross.
//    - This program MIGHT work with other combinations
//      but is untested. 
//    - 
//
// Notes:
//    - This script calculates a trajectory using the Patched Conic Formula method.
//      The vessel will follow the trajectory as calculated by the formulas,
//      no correction burns are done.
//    - The Patched Conic method breaks the trajectory down into segments
//      which are "patched" together (hence the name).
//
//      These types of transfers are handled:
//
//      Transfer from a body to another body within the same SOI:
//        1.  Hyperbolic escape from a parking orbit around the departure
//            body.
//        2.  Elliptical orbit to the arrival body.
//        3.  Hyperbolic capture or a flyby at the arrival body.
//
//      Transfer from a body to a vessel within the same SOI:
//        1.  Hyperbolic escape from a parking orbit around the departure
//            body.
//        2.  Elliptical orbit to another vessel.
//        3.  Flyby of the arrival vessel.
//
//    - Lots of orbits to keep track of:
//        Parking               - Parking orbit around the departure body.
//        Capture               - Orbit after capture at the arrival body.
//        Departure             - Orbit of the body departed from.
//        Arrival               - Orbit of the body or ship arrived at.
//        Hyperbolic Departure  - Hyperbolic orbit from parking orbit to the
//                                SOI of the body departed from.
//        Hyperbolic Arrival    - Hyperbolic orbit from the SOI of the body
//                                arrived at.
//        Elliptical            - Elliptical transfer orbit from the
//                                departure body SOI to the arrival
//                                orbital.
//
//    - Abbreviations used in the orbital calculations (they are reasonably common):
//        a is the semi-major axis.
//        e is eccentricity.
//        E is eccentric anomaly.
//        F is hyperbolic eccentric anomaly.
//        M is mean anomaly.
//        mu is Standard Gravitational Parameter. 
//        nu is true anomaly.
//        r is radius of an orbit.
//        SOE is Specific Orbital Energy.
//        t is time.
//        v is speed. 
//    -         
//
// Todo:
//    - Test a Kerbin to Eve transfer.
//    - Investigate the timewarp failures.
//    - Test the capture option.
//    - Add check to ensure there is enough time
//      to steer and burn before reaching the maneuver point.
//    - Think about error conditions such as target name not found etc.
//    - Add error checking to ensure the departure and arrival
//      orbital combinations are valid.
//    -
//
// Update History:
//    10/01/2022 V01  - Created.
//    11/03/2022 V02  - WIP.
//                    - Fixed up some of the doco.
//                    - Fixed up Hill Search algorithm, it was not
//                      working very well.
//                    - Removed the burn tuning using feedback, it
//                      works but I decided it goes against the 
//                      spirit of this kind of script.
//                    - Added an adjustment to correctly allow for the
//                      flight time from the parking orbit to
//                      the SOI during the hyperbolic escape.
//
@lazyglobal off.
// Increase IPU value to speed up scripts with a lot of calculations
// if the CPU and graphic card are good. Default is around 200.
// Max is around 2000.
set config:ipu to 2000.

// Parameter descriptions.        
//    OrbitalName             Name of the target orbital.
//    EncounterType           Type of encounter "CAPTURE" or "FLYBY".
//                            at the target planet or moon (km).
//                            For a flyby set to zero.
//    SearchgStepSize         Step size to use in search (s).   
//    SteeringDuration        Time to allow the vessel to steer to the burn
//                            attitude for the maneuver (s).                            
//	  WarpType	  					  "PHYSICS","RAILS" or "NOWARP".

parameter OrbitalName to "".
parameter EncounterType to "CAPTURE".
parameter SearchStepSize to 600.
parameter SteeringDuration to 60.
parameter WarpType to "NOWARP".

// Load in library functions.
runoncepath("PlanetTransferHillClimbingMFD V02").
runoncepath("Delta-vFunctions V03").
runoncepath("OrbitFunctions V04").
runoncepath("MiscFunctions V04").

local NextMFDRefreshTime to time:seconds.
local ArrivalOrbital to 0.
local EjectionAngle to 0.
local BurnStartTimeUT to time(0).
local FatalError to false.
local MFDRefreshTriggerActive to true.
local StagingTriggerActive to true.
local lock ShipPositionVec to ship:position-ship:body:position.

// Warning: Orbital State Vector invariants should be recalculated
// when used to ensure the values are up to date; the co-ordinate system "drifts"
// over time.
local lock ShipObtNormalVec to vcrs(ShipPositionVec,ship:velocity:obt).
local lock ArrivalObtSAMVec to
  CalcSAMVec
    (
      ArrivalOrbital:obt:position-ArrivalOrbital:body:position,
      ArrivalOrbital:obt:velocity:orbit
    ).
local lock ArrivalObtEccVec to
  CalcEccentricityVec
    (
      ArrivalOrbital:obt:position-ArrivalOrbital:body:position,
      ArrivalOrbital:obt:velocity:orbit,
      ArrivalOrbital:body:mu
    ).
local SynodicPeriod to 0.
local StepSize to 0.
local BeforeScore to 0.
local BestScore to 0.
local BestEllipticalStartUT to 0.
local LogFilename to kuniverse:realtime:tostring+".txt".

// Debugging aids. Comment out if not needed.
local EllipticalEndArrow to
  vecdraw(V(0,0,0),V(0,0,0),red,"Elliptical End Position",1,false,0.1,true,true).
local ArrivalOrbitalArrow to
  vecdraw(V(0,0,0),V(0,0,0),green,"Arrival Orbital Position",1,false,0.1,true,true).

sas off.
set ship:control:mainthrottle to 0.
lock throttle to 0.
clearvecdraws().
SetStagingTrigger().
GetArrivalOrbital().
SetMFD().
CheckForErrorsAndWarnings().
if not FatalError
  {
    SearchForEllipticalStartTime1().
    PhasingWaitAndEscapeBurn().
    WaitForEllipticalEndTime().
    if bodyExists(OrbitalName)
      {
        if EncounterType = "CAPTURE"
          and ship:body:name = ArrivalOrbital:name
          CaptureBurn().
      }
  }
RemoveLocksAndTriggers().

local function SearchForEllipticalStartTime1
  {
// Search for the time to start the elliptical transfer
// orbit.
// Notes:
//    - Hill Climbing Search.
//    - This search may fail sometimes (especially with small step
//      sizes) as closest approach using departure time may have 
//      plateaus and local hills.
//    -
// Todo:
//    - 

// Constants used to control the search.
//    acceleration  - A factor used to increase/decrease the step size
//                    during the search. This will increase speed at the
//                    cost of accuracy.
//    epsilon       - Used to decide when to stop the search.
//                    It defines the minimum improvement in the best
//                    score for the search to continue.
    local acceleration to 1.
    local epsilon to 1. // Metres.

    local SearchFromUT to time.
    local SearchToUT to SearchFromUT+SynodicPeriod.
    local StartUT to SearchFromUT+SynodicPeriod/2.
    local TestUT to 0.
    local StepMethod to list().
    local step to 0.
    local BestStep to 0.
    local score to 0.
    local OutOfBounds to false.
    
    StepMethod:add(acceleration).
    StepMethod:add(1/acceleration).
    StepMethod:add(-acceleration).
    StepMethod:add(-1/acceleration).

    PlanetTransferHillClimbingMFD["DisplayFlightStatus"]("Elliptical srch").

    set StepSize to SearchStepSize.
    set Score to CalcEllipticalScore(StartUT).
    log score to LogFilename.
    set BestScore to score.

    until false
      {
        set BestStep to 0.
        set BeforeScore to BestScore.
        set OutOfBounds to false.
        for method in StepMethod
          {
            set step to StepSize+method.
            set TestUT to StartUT+step.
            if TestUT < SearchFromUT
              or TestUT > SearchToUT
              set OutOfBounds to true.  
            set score to CalcEllipticalScore(TestUT).
            log score to LogFilename.
            if score < BestScore
              {
                set BestScore to score.
                set BestStep to step.
              }
          }
        log BestScore+" "+(BeforeScore-BestScore)+" "+BestStep to LogFilename.
        if OutOfBounds
          {
            set StartUT to
              SearchFromUT+random()*(SearchToUT-SearchFromUT).
            set Score to CalcEllipticalScore(StartUT).
            set BestScore to score.
            set StepSize to SearchStepSize.
            log "Out of bounds" to LogFilename.
          }
        else
          {
            if BestStep = 0
              {
                set StepSize to StepSize-acceleration.
              }
            else
              {
                set StartUT to StartUT+BestStep.
                set StepSize to BestStep.
              }
            if BeforeScore-BestScore < epsilon
              break.
          }
      }
    set BestEllipticalStartUT to StartUT.
    set EllipticalEndArrow:show to false.
    set ArrivalOrbitalArrow:show to false.
  }

local function SearchForEllipticalStartTime2
  {
// Search for the time to start the elliptical transfer
// orbit.
// Notes:
//    - Exhaustive Search.
//    -
// Todo:
//    - 

    local SearchFromUT to time.
    local SearchToUT to SearchFromUT+SynodicPeriod.
    local StartUT to SearchFromUT.
    local score to 0.
    
    PlanetTransferHillClimbingMFD["DisplayFlightStatus"]("Transfer search").

    set BestScore to 1E64.
    set StepSize to SearchStepSize.

    until StartUT > SearchToUT
      {
        set score to CalcEllipticalScore(StartUT).
//        log (TransferPointUT-SearchFromUT):seconds+","+score[0] to LogFilename.
        if score < BestScore
          {
            set BestScore to score.
            set BestEllipticalStartUT to StartUT.
          }
        set StartUT to StartUT+StepSize.
      }
        
    set EllipticalEndArrow:show to false.
    set ArrivalOrbitalArrow:show to false.
  }

local function PhasingWaitAndEscapeBurn
  {
// Phasing wait and escape burn.
// Notes:
//    - Escape from the departure SOI by performing a maneuver
//      from the parking orbit that results in
//      a hyperbolic excess speed (v infinity) sufficient to get to
//      the arrival orbit via an elliptical transfer orbit.
//    - The elliptical transfer orbit "starts" when the ship
//      crosses the departure SOI boundary while escaping, not when the
//      burn is done. An adjustment is made for this time.
//    - The classic formula for the hyperbolic SMA is a = -mu/vInfinity^2
//      which assumes vInfinity applies at infinity, but this is not
//      correct for a KSP SOI which has a finite size. A Specific
//      Orbital Energy (SOE) formula is used to calculate the hyperbolic SMA
//      and the hyperbolic velocity; it gives more accurate results.
//    -     
// Todo:
//    - Allow for ejection angle alignment wait, steering wait
//      etc.
//    - 

    local rDeparture to
      ship:body:body:altitudeof(positionat(ship:body,BestEllipticalStartUT))
        +ship:body:body:radius.
    local rEllipticalEnd to CalcEllipticalEndRadius(BestEllipticalStartUT).
    local rParking to ship:altitude+ship:body:radius.
    local vDeparture to velocityat(ship:body,BestEllipticalStartUT):obt:mag.
    local vParking to sqrt(ship:body:mu/rParking).
    local vInfinity to
      CalcvInfinity
        (
          vDeparture,
          rDeparture,
          rEllipticalEnd,
          ship:body:body:mu
        ).
//    local vHyperbolic to sqrt(ship:body:mu*(2/rParking-1/aHyperbolic)).
    local SOEHyperbolicAtSOI to
      CalcSpecificOrbitalEnergy(vInfinity,ship:body:SOIRadius,ship:body:mu).
    local vHyperbolic to
      sqrt(2*(SOEHyperbolicAtSOI+ship:body:mu/rParking)).
    local aHyperbolic to -ship:body:mu/vInfinity^2.
//    local aHyperbolic to -ship:body:mu/(2*SOEHyperbolicAtSOI).
    local eHyperbolic to 1-rParking/aHyperbolic.
    local TimeToSOI to
      CalcTimeToSOIHyperbolic
        (
          ship:body:SOIRadius,
          aHyperbolic,
          ship:body:mu,
          eHyperbolic
        ).
    local EscapeStartUT to BestEllipticalStartUT-TimeToSOI.
//    local EscapeStartUT to BestEllipticalStartUT.
    local BurnDeltav to vHyperbolic-vParking.
    log
    (
      round(vDeparture,1)+" "
      +round(vParking,1)+" "
      +round(vInfinity,1)+" "
      +round(vHyperbolic,1)+" "
      +round(BurnDeltav,1)+" "
      +round(rDeparture,1)
    ) to LogFilename.

// Ejection angle is the angle the trajectory of the ship is turned
// by gravity while escaping to the edge of the SOI.
    set EjectionAngle to arcCos(-1/eHyperbolic).

    PlanetTransferHillClimbingMFD["DisplayFlightStatus"]("Phasing wait").

    if WarpType = "NOWARP"
      wait until time > EscapeStartUT.
    else
      {
// There is something not right with the timewarping here and how
// the kOS code behaves after the timewarp has completed. Extra code
// has been added to ensure the timewarp has completed and the
// SHIP-related values have been updated completely.
        set kuniverse:timewarp:mode to WarpType.
        kuniverse:timewarp:warpTo(EscapeStartUT:seconds).
        wait until time > EscapeStartUT.
        wait until kuniverse:timewarp:rate = 1.
        wait until ship:unpacked.
        wait 0.
      }

    local AngleToManeuverPoint to
      CalcAngleToEjectionPoint
        (
          EjectionAngle,
          rDeparture,
          rEllipticalEnd
        ).
    local ManeuverPointUT to
      time+AngleToManeuverPoint*ship:obt:period/360.

    local BurnDuration to
      DeltavEstBurnTime
        (
          BurnDeltav,
          ship:mass,
          ship:availablethrust,
          ISPVesselStage()
        ).
    set BurnStartTimeUT to ManeuverPointUT-BurnDuration/2.
    PlanetTransferHillClimbingMFD["DisplayManuever"](BurnDuration,BurnDeltav).
    PlanetTransferHillClimbingMFD["DisplayFlightStatus"]("Eject ang wait").

// Check to see if there is enough time to do the burn,
// stop the program if not.
    if time > (BurnStartTimeUT-SteeringDuration)
      {
        PlanetTransferHillClimbingMFD["DisplayError"]("Not enough time for escape burn").
//        print 0/0.
      }
    kuniverse:pause().
    if WarpType = "NOWARP"
      wait BurnStartTimeUT:seconds-SteeringDuration-time:seconds.
    else
      {
        wait 0.
        set kuniverse:timewarp:mode to WarpType.
        kuniverse:timewarp:warpTo(BurnStartTimeUT:seconds-SteeringDuration).
        wait until time > BurnStartTimeUT-SteeringDuration.
        wait until kuniverse:timewarp:rate = 1.
        wait 0.
      }

    local BurnVec to velocityat(ship,ManeuverPointUT):obt:normalized.
    local SteeringDir to lookdirup(BurnVec,ship:facing:topvector).
    lock steering to SteeringDir.

    PlanetTransferHillClimbingMFD["DisplayFlightStatus"]("Steering").
    wait SteeringDuration.

    PlanetTransferHillClimbingMFD["DisplayFlightStatus"]("Escape burn").
    EscapeBurn
      (
        BurnVec,
        BurnDuration
      ).
    set BurnStartTimeUT to time(0).
    PlanetTransferHillClimbingMFD["DisplayFlightStatus"]("Escaping").

    if WarpType = "NOWARP"
      wait until ship:obt:transition <> "ESCAPE".
    else
      {
        wait 1. // Stop cannot timewarp while under acceleration error.
        set kuniverse:timewarp:mode to WarpType.
//        set kuniverse:timewarp:rate to 10000. 
        wait until ship:obt:transition <> "ESCAPE".
        kuniverse:timewarp:cancelwarp().
        wait until kuniverse:timewarp:rate = 1.
        wait 0.
      }
  }

local function CalcvInfinity
  {
// Calculate the vInfinity required to transfer a ship from
// the orbit of a departure body to the orbit of another
// ship or body in the same SOI.
// Notes:
//    - vInfinity is also called the hyperbolic excess speed.
//    -
// Todo:
//    -

    parameter vDeparture.
    parameter rDeparture.
    parameter rArrival.
    parameter mu.

    local aElliptical to (rDeparture+rArrival)/2.
    local vElliptical to sqrt(mu*(2/rDeparture-1/aElliptical)).  
    local vInfinity to vElliptical-vDeparture.

    return vInfinity.
  }

local function CalcSpecificOrbitalEnergy
  {
// Calculate the specific orbital energy.
// Notes:
//    - The symbol is lower case Epsilon. SOE
//      (specific orbital energy) is used here as
//      e and E are already taken. 
//    -
// Todo:
//    -

    parameter v.
    parameter r.
    parameter mu.

    local SOE to v^2/2-mu/r.

    return SOE.
  }

local function CalcTimeToSOIHyperbolic
  {
// Calculate the time of flight from the burn point to the SOI boundary
// for a hyperbolic orbit.
// Notes:
//    -
// Todo:
//    -
    parameter SOIRadius.
    parameter a.
    parameter mu.
    parameter e.

    local t to 0.
    local nu to 0.
    local nu0 to 0.
    local F to 0.
    local F0 to 0.
    local FRad to 0.
    local F0Rad to 0.

    set nu0 to 0.
    set nu to CalcTrueAnomalyFromRadiusH(SOIRadius,a,e).
    set F to CalcEccentricAnomalyH(nu,e).
    set FRad to F*constant:degtorad.
    set F0 to CalcEccentricAnomalyH(nu0,e).
    set F0Rad to F0*constant:degtorad.

    set t to sqrt((-a)^3/mu)*((e*CalcSinh(F)-FRad)-(e*CalcSinh(F0)-F0Rad)).
    return t.
  }

local function CalcAngleToEjectionPoint
  {
// Calculate the current angle from the ship to the hyperbolic ejection point.
// Notes:
//    - Calculate the ejection angle and burn point required to align
//      the asymptote of the hyperbolic orbit with the prograde/retrograde
//      direction of body in it's orbit.
//      Ejection angle is measured clockwise from prograde/retrograde.
//    - This code relies on a vector cross product 'trick' to find the correct quadrant to
//      calculate a 0-360 angle using the VANG function, so use with
//      caution.
//    -
// Todo:
//    -

    parameter EjectionAng.
    parameter rDeparture.
    parameter rArrival.

    local ProgradeVec to ship:body:obt:velocity:obt.
    local angle to 0.
    if rArrival > rDeparture
      {
        local AngleToPrograde to 0.
        if vang(ShipPositionVec,vcrs(ShipObtNormalVec,ProgradeVec)) < 90
          set AngleToPrograde to 360-vang(ShipPositionVec,ProgradeVec).
        else
          set AngleToPrograde to vang(ShipPositionVec,ProgradeVec).
        set Angle to mod(AngleToPrograde-EjectionAng,360).
      }
    else
      {
        local AngleToRetrograde to 0.
        if vang(ShipPositionVec,vcrs(ShipObtNormalVec,-ProgradeVec)) < 90
          set AngleToRetrograde to 360-vang(ShipPositionVec,-ProgradeVec).
        else
          set AngleToRetrograde to vang(ShipPositionVec,-ProgradeVec).
        set Angle to mod(AngleToRetrograde-EjectionAng,360).
      }
    if angle < 0
      set angle to angle+360.

    return angle.
  }

local function WaitForEllipticalEndTime
  {
// Wait for the elliptical transfer orbit to reach it's end.
// Notes:
//    - The elliptical transfer ends when the next SOI is encountered, or the
//      apoapsis/periapsis is reached.
//    - FYI Last checked 15/12/2021. KSP has a bug where the future ENCOUNTER
//      transition info disappears when timewarping near
//      the transition, it gets set to the following FINAL transition info
//      ie it is like the encounter does not happen. Once the vessel transitions
//      into the encounter SOI, the info is updated correctly.
//    -
// Todo:
//    -

    local TimeToTransferEnd to 0.

    PlanetTransferHillClimbingMFD["DisplayFlightStatus"]("Transfering").
    if bodyExists(OrbitalName) and ship:obt:transition = "ENCOUNTER"
      set TimeToTransferEnd to ship:obt:eta:transition.
    else
      {
        if ArrivalOrbital:altitude > ship:altitude
          set TimeToTransferEnd to ship:obt:eta:apoapsis.
        else
          set TimeToTransferEnd to ship:obt:eta:periapsis.
      }
      
    if WarpType = "NOWARP"
      wait TimeToTransferEnd.
    else
      {
        set kuniverse:timewarp:mode to WarpType.
        kuniverse:timewarp:warpTo(time:seconds+TimeToTransferEnd).
        wait TimeToTransferEnd.
        wait until kuniverse:timewarp:issettled.
      }

// Ensure that the encounter with the SOI is complete.
    print 0/0.  // FIX THIS BUG!
    if bodyExists(OrbitalName) and ship:obt:transition = "ENCOUNTER"
      wait until ship:obt:body:name = ArrivalOrbital:body:name.
  }

local function CaptureBurn
  {
// Capture burn.
// Notes:
//    - The capture burn is done at the periapsis of the hyperbolic
//      orbit at arrival. The capture radius is the periapsis.
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
    PlanetTransferHillClimbingMFD["DisplayManuever"](BurnDuration,BurnDeltav).
    PlanetTransferHillClimbingMFD["DisplayFlightStatus"]("Capture wait").

// Check to see if there is enough time to do the burn,
// stop the program if not.
    if time > (BurnStartTimeUT-SteeringDuration)
      {
        PlanetTransferHillClimbingMFD["DisplayError"]("Not enough time for capture burn").
        print 0/0.
      }
//    kuniverse:pause().
    if WarpType = "NOWARP"
      wait BurnStartTimeUT:seconds-SteeringDuration-time:seconds.
    else
      {
        set kuniverse:timewarp:mode to WarpType.
        kuniverse:timewarp:warpTo(BurnStartTimeUT:seconds-SteeringDuration).
        wait BurnStartTimeUT:seconds-SteeringDuration-time:seconds.
        wait until kuniverse:timewarp:issettled.
      }

    set BurnVec to -velocityat(ship,ManeuverPointUT):obt.
    set SteeringDir to lookdirup(BurnVec,ship:facing:topvector).
    lock steering to SteeringDir.

    PlanetTransferHillClimbingMFD["DisplayFlightStatus"]("Steering").
    wait SteeringDuration.

    PlanetTransferHillClimbingMFD["DisplayFlightStatus"]("Capture burn").
    lock throttle to 1.
    wait BurnDuration.
    lock throttle to 0.
    unlock steering.
    PlanetTransferHillClimbingMFD["DisplayFlightStatus"]("").

  }

local function EscapeBurn
  {
// Escape burn.
// Notes:
//    - 
// Todo:
//    - 

    parameter BurnVec.
    parameter BurnDuration.

    local ThrottleSet to 0.

    lock throttle to Throttleset.
    lock steering to lookDirUp(BurnVec,ship:facing:topvector).

    set Throttleset to 1.
    wait BurnDuration.
    set ThrottleSet to 0.
    unlock throttle.
    unlock steering.
  }

local function CalcEllipticalScore
  {
// Calculate a score for a elliptical transfer orbit that starts at
// a given time.
// Notes:
//    - The evaluation 'score' is how close the end
//      of the elliptical transfer orbit will get to the arrival orbital.
//    -
// Todo:
//    - Allow for transfer to orbitals closer to the sun.
//    - Test to see what happens when the departure and arrival
//      orbits are inclined.
//    - Is there a better method to calculate where the apsis
//      of the transfer orbit intersects the arrival orbit?
//    -

    parameter StartUT.

    local rDeparture to
      ship:body:body:altitudeof(positionat(ship:body,StartUT))+ship:body:body:radius.
    local rEllipticalEnd to CalcEllipticalEndRadius(StartUT).  
    local aElliptical to (rDeparture+rEllipticalEnd)/2.
    local tTransfer to constant:pi*sqrt(aElliptical^3/ship:body:body:mu).
    local EllipticalEndUT to StartUT+tTransfer.
    local DeparturePositionVec to positionat(ship:body,StartUT)-ship:body:body:position.
    local EllipticalApsisVec to -(DeparturePositionVec):normalized.
    local EllipticalEndPositionVec to EllipticalApsisVec*rEllipticalEnd.
    local ArrivalOrbitalPositionVec to positionat(ArrivalOrbital,EllipticalEndUT)-ArrivalOrbital:body:position.

    local ClosestApproach to (EllipticalEndPositionVec-ArrivalOrbitalPositionVec):mag.

    // Vecdraws for debugging. Comment out if not required.
    {
      set EllipticalEndArrow:start to ship:body:body:position.
      set EllipticalEndArrow:vec to EllipticalEndPositionVec.
      set EllipticalEndArrow:show to true.

      set ArrivalOrbitalArrow:start to ship:body:body:position.
      set ArrivalOrbitalArrow:vec to ArrivalOrbitalPositionVec.
      set ArrivalOrbitalArrow:show to true.
    }

    return ClosestApproach. 
  }

local function CalcEllipticalEndRadius
  {
// Calculate the radius at the end of the elliptical transfer orbit
// where the orbit starts at a given time.
// Notes:
//    - I cannot think of a good name for this function.
//    - The calculation should allow for orbit eccentricity but
//      not allow for any relative inclination between orbits.
//    - The calculation takes advantage of the fact the elliptical transfer orbit
//      ends 180 degrees from it's start, this allows many simplifying
//      assumptions to be made.
// Todo:
//    -

    parameter StartUT.

    local DeparturePositionVec to positionat(ship:body,StartUT)-ship:body:body:position.
    local EllipticalApsisVec to -DeparturePositionVec:normalized.
    local nuArrivalOrbital to
      CalcTrueAnomalyFromVec
        (
          EllipticalApsisVec,
          ArrivalObtEccVec,
          ArrivalObtSAMVec
        ).
    local rEllipticalEnd to
      CalcOrbitRadius(nuArrivalOrbital,ArrivalOrbital:obt:eccentricity,ArrivalOrbital:obt:semimajoraxis).

    return rEllipticalEnd.
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
    set terminal:height to 21.
    PlanetTransferHillClimbingMFD["DisplayLabels"]
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
        PlanetTransferHillClimbingMFD["DisplayRefresh"]
         (
          ship:obt:apoapsis,
          ship:obt:periapsis,
          ship:obt:eccentricity,
          EjectionAngle,
          StepSize,
          BeforeScore,
          BestScore,
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
//    -
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

    set SynodicPeriod to
      1/abs(1/ship:body:obt:period-1/ArrivalOrbital:obt:period).
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
        PlanetTransferHillClimbingMFD["DisplayError"]("Encounter type is unknown").
        set FatalError to true.
      }
    else
    if EncounterType = "CAPTURE"
      and not bodyExists(OrbitalName)
      {
        PlanetTransferHillClimbingMFD["DisplayError"]("Capture only valid for planet or moon").
        set FatalError to true.
      }
    else
    if OrbitalName = ship:ShipName
      {
        PlanetTransferHillClimbingMFD["DisplayError"]("Target orbital name same as this vessel").
        set FatalError to true.
      }
    else
    if ship:orbit:eccentricity >= 0.01
      PlanetTransferHillClimbingMFD["DisplayError"]("Parking orbit is not circular").
    else
    if ArrivalOrbital:obt:eccentricity >= 0.01
      PlanetTransferHillClimbingMFD["DisplayError"]("Arrival orbit is not circular").
    else
    if CalcRelativeInclination
        (
          vcrs(ship:body:obt:position-ship:body:body:position,ship:body:obt:velocity:orbit),
          vcrs(ArrivalOrbital:obt:position-ArrivalOrbital:body:position,ArrivalOrbital:obt:velocity:orbit)
        ) > 0.5
      PlanetTransferHillClimbingMFD["DisplayError"]("Arrival orbit is inclined to departure orbit").
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

local function CalcEccentricAnomalyH
  {
// Hyperbolic Eccentric Anomaly in degrees.
// Notes:
//    -
// Todo:
//    -

    parameter nu.
    parameter e.

    local F to 0.

    set F to CalcArccosh((e+cos(nu))/(1+e*cos(nu))).

    return F.
  }

local function CalcCosh
  {
// Hyperbolic cosine function input degrees.

    parameter angle.

    local coshx to 0.
    local radians to 0.

    set radians to angle*constant:degtorad.
    set coshx to (constant:e^radians+constant:e^(-radians))/2.

    return coshx. 
  }

local function CalcSinh
  {
// Hyperbolic sine function input degrees.

    parameter angle.

    local sinhx to 0.
    local radians to 0.

    set radians to angle*constant:degtorad.
    set sinhx to (constant:e^radians-constant:e^(-radians))/2.

    return sinhx. 
  }

local function CalcArccosh
  {
// Inverse hyperbolic cosine function output degrees.

    parameter x.

    local arccoshx to 0.

    set arccoshx to ln(x+sqrt(x^2-1)).

    return arccoshx*constant:radtodeg.
  }

local function CalcTrueAnomalyFromRadiusH
  {
// Calculate the true anomaly from radius for a
// hyperbolic orbit output degrees.

    parameter r.
    parameter a.
    parameter e.

    local nu to 0.

    set nu to arccos((a*(1-e^2)-r)/(e*r)).

    return nu.
  }
