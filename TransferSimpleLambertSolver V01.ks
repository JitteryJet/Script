// Name: TransferSimpleLambertSolver
// Author: JitteryJet
// Version: V01
// kOS Version: 1.3.2.0
// KSP Version: 1.12.3
// Description:
//    Transfer the ship from it's current orbit to
//    another orbital sharing the same central body.
//
// Assumptions:
//    - No staging is required.
//    - The departure and arrival orbits are prograde (anticlockwise)
//      defined by north being up. The code MIGHT work with 
//      retrograde orbits but is untested.
//    - 
//
// Notes:
//    - This script finds a transfer orbit using a simple Lambert's Solver.
//      "Short Way" elliptical transfer orbits only.
//
//    - The departure and arrival orbits must share the same central
//      body (ie be in the same SOI). These transfers are handled:
//
//        - Transfer to the arrival body with a flyby or a capture.
//        - Transfer to the arrival ship with a flyby.
//
//    - Lots of orbits to keep track of:
//        Departure             - Ship's current orbit.
//        Arrival               - Orbit of the body or ship arrived at.
//        Capture               - Ship's orbit after capture at the arrival body.
//        Hyperbolic Arrival    - Ship's orbit after encountering the SOI of the arrival body.
//        Transfer              - Ship's transfer orbit to the arrival body or ship.      
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
//
//    - The algorithm is based mostly on the YouTube video series 
//      "AEE462 Lecture 10 - A Bisection Algorithm for the Solution of Lambert's Equation"
//      by M Peet, YouTube channel "Cybernetic Systems and Controls".  
//
// Todo:
//    - Add staging.
//    - Add code to terminate the program if another body interfers
//      with the transfer (yes I am looking at you, Mun).
//    - Optimise run time by reusing the Alpha and Beta angle values
//      in Lambert's Equation instead of recalculating them.
//      Benchmark change in performance to ensure it is worth doing.
//    - Have another look at how a safe periapsis height is guaranteed
//      at the end of the transfer orbit. Periapsis as a parameter?
//      Ignore Lambert's Solver solutions where the ship will crash
//      into the arrival body? Formula to calculate the velocity change
//      required to adjust the periapsis during a hyperbolic encounter? 
//    -
//
// Update History:
//    15/07/2022 V01  - Created.
//                    -
//
@lazyglobal off.
// Increase IPU value to speed up scripts with a lot of calculations
// if the CPU and graphic card are good. Default is around 200.
// Max is around 2000.
set config:ipu to 2000.

// Parameter descriptions.        
//    OrbitalName             Name of the target orbital.
//    ArrivalAction           Action at arrival "CAPTURE" or "FLYBY".
//    SearchType              Search type "LOWESTDV" or "LOWESTTIME".
//    SearchStepSize          Step size to use in search (s).   
//    SteeringDuration        Time to allow the vessel to steer to the burn
//                            attitude for the maneuver (s).                            
//	  WarpType	  					  "PHYSICS","RAILS" or "NOWARP".
//    ShowArrows              "SHOW" or "NOSHOW".
//    

parameter OrbitalName to "".
parameter ArrivalAction to "CAPTURE".
parameter SearchType to "LOWESTDV".
parameter SearchStepSize to 600.
parameter SteeringDuration to 60.
parameter WarpType to "NOWARP".
parameter ShowArrows to "NOSHOW".

// Load in library functions.
runoncepath("TransferSimpleLambertSolverMFD V01").
runoncepath("Delta-vFunctions V03").
runoncepath("MiscFunctions V04").

local NextMFDRefreshTime to time:seconds.
local ArrivalOrbital to 0.
local ManeuverStartTStmp to timestamp(0).
local ManeuverVec to 0.
local FatalError to false.
local MFDRefreshTriggerActive to true.
local VeryBigNumber to 3.402823E+38.
local SteeringTSpan to timespan(0,0,0,0,SteeringDuration).

// Minimum height above the atmosphere (or sea level for airless)
// where an orbit is considered safe.
local SafeOrbitMargin to 10*1000.
local SafeOrbitAlt to 0.

// Warning: Orbital State Vector invariants should be recalculated
// when used to ensure the values are up to date, the origins and
// axes move over time.
local lock ShipPositionVec to ship:position-ship:body:position.
local lock ShipObtNormalVec to vcrs(ShipPositionVec,ship:velocity:obt).

local tDepTStmp to time(0).
local tTransTSpan to timespan(0).
local aFinalTrans to 0.
local vFinalTransDv to 999999.
local tFinalTransTSpan to timespan(99999,0).
local tFinalDepTStmp to timestamp().

// Log file for debugging.
local LogFilename to kuniverse:realtime:tostring+".txt".

local DepartureArrow to
  vecdraw(V(0,0,0),V(0,0,0),red,"Departure Position",1,false,0.1,true,true).
local ArrivalArrow to
  vecdraw(V(0,0,0),V(0,0,0),green,"Arrival Position",1,false,0.1,true,true).
//local VacantFocusArrow to
//  vecdraw(V(0,0,0),V(0,0,0),yellow,"Vacant Focus",1,false,0.1,true,true).

sas off.
set ship:control:mainthrottle to 0.
clearvecdraws().
GetArrivalOrbital().
SetMFD().
CheckForErrorsAndWarnings().
if not FatalError
  {
    SearchForTransfer().
    StartTransfer().
    HandleArrival().
  }
MFDFunctions["DisplayFlightStatus"]("Finished").
RemoveLocksAndTriggers().

local function SearchForTransfer
  {
// Search combinations of departure times and transfer times for
// a suitable transfer orbit.
// Notes:
//    - Search for "Short Way" elliptical transfer orbits only.
//      This simplifies the code. But it will miss other optimal solutions.
//    - The minimum transfer time defines the parabolic transfer orbit
//      solution: times greater than this give elliptical transfer orbits.
//    - The maximum transfer time defines the upper limit for the
//      "Short Way" solutions, transfer times longer than this
//      are "Long Way" solutions.
//    -
// Todo:
//    - Think some more about how far into the future to search for
//      solutions.
//    - Cater for "Long Way" solutions.
//    -

    MFDFunctions["DisplayFlightStatus"]("Solution search").

    local tDepFromTStmp to timestamp()+300.
    local tDepToTStmp to tDepFromTStmp+ship:obt:period.
    local tTransToTSpan to ArrivalOrbital:obt:period.

    local r1 to 0.                          // Orbit radius of Point1.
    local r2 to 0.                          // Orbit radius of Point2.
    local c to 0.                           // Chord Point1-Point2.
    local mu to 0.                          // Standard Gravitational Parameter
    local aTrans to 0.                      // SMA of transfer orbit.
    local tMinTransTSpan to timespan(0).    // Minimum transfer time (TOF). Defines the parabolic solution.
    local tMaxTransTSpan to timespan(0).    // Maximum transfer time (TOF).
    local aMinSOETrans to 0.                // Minimum energy transfer semi-major axis.
    local vDeltaVec to 0.

// Always recalculate the position vectors just prior to being used,
// the position vector origin and axes of the central body moves in real time
// in the KSP coordinate space.
    local r1Vec to 0.
    local r2Vec to 0.

    set mu to ship:body:mu.
    if ShowArrows = "SHOW"
      {
        set DepartureArrow:show to true.
        set ArrivalArrow:show to true.
      }

    set tDepTStmp to tDepFromTStmp.

    until tDepTStmp > tDepToTStmp
      {
        set tTransTSpan to timespan(0).
        until tTransTSpan > tTransToTSpan
          { 
            if tDepTStmp < time()
              {
                MFDFunctions["DisplayError"]("Cannot search in the past. Search is too slow.").
                print 0/0.
              }
            set r1Vec to positionat(ship,tDepTStmp)-ship:body:position.
            set r2Vec to positionat(ArrivalOrbital,tDepTStmp+tTransTSpan)-ship:body:position.
            set r1 to r1Vec:mag.
            set r2 to r2Vec:mag.
            set c to (r2Vec-r1Vec):mag.
            set aMinSOETrans to (r1+r2+c)/4.
            set tMinTransTSpan to CalcParabolicTransferTime(r1,r2,c,mu).
            set tMaxTransTSpan to CalcTransferTimeLamberts(r1,r2,c,aMinSOETrans,mu).
            if ShowArrows = "SHOW"
              {
                set DepartureArrow:start to ship:body:position.
                set DepartureArrow:vec to r1Vec.
                set ArrivalArrow:start to ship:body:position.
                set ArrivalArrow:vec to r2Vec.
              }
            if SearchType = "LOWESTTIME"
              {
                if tTransTSpan > tMinTransTSpan
                  and tTransTSpan < tMaxTransTSpan
                  {
                    if tTransTSpan < tFinalTransTSpan
                      {
                        set tFinalDepTStmp to tDepTStmp.
                        set tFinalTransTSpan to tTransTSpan.
                        set aFinalTrans to CalcSMALamberts(tFinalTransTSpan,r1,r2,c,mu).
                        set vDeltaVec to
                          CalcTransfervVec(r1Vec,r2Vec,aFinalTrans,mu)-velocityat(ship,tDepTStmp):orbit.
                        set vFinalTransDv to vDeltaVec:mag.
                      }
                  }
              }
            else
            if SearchType = "LOWESTDV"
              {
                if tTransTSpan > tMinTransTSpan
                  and tTransTSpan < tMaxTransTSpan
                  {
                    set aTrans to CalcSMALamberts(tTransTSpan,r1,r2,c,mu).
                    set vDeltaVec to
                      CalcTransfervVec(r1Vec,r2Vec,aTrans,mu)-velocityat(ship,tDepTStmp):orbit.
                    if vDeltaVec:mag < vFinalTransDv
                      {
                        set vFinalTransDv to vDeltaVec:mag.
                        set aFinalTrans to aTrans.
                        set tFinalDepTStmp to tDepTStmp.
                        set tFinalTransTSpan to tTransTSpan.
                      }
                  }
              }
            set tTransTSpan to tTransTSpan+SearchStepSize.
          }
        set tDepTStmp to TDepTStmp+SearchStepSize.
      }
    MFDFunctions["DisplaySearchResults"]
      (
        tFinalDepTStmp-timestamp(),
        tFinalTransTSpan,
        aFinalTrans,
        vFinalTransDv
      ).
    set DepartureArrow:show to false.
    set ArrivalArrow:show to false.
  }

local function CalcSMALamberts
  {
// Calculate the semi-major axis given a transfer time using Lambert's Equation.
// Notes:
//    - Uses the Bisection algorithm.
//    - Elliptical orbits only.
//    - "Short Way" solutions only.
//    - This is only a simple implemetation of a Lambert Solver,
//      it will probably fail in complex situations?
//    - 
// Todo:
//    - It probably is not too much work to extend this algorithm
//      to handle "Long Way" solutions as well.
//    -     

    parameter t.        // Transfer time (TOF) from Point1 to Point2.
    parameter r1.       // Orbit radius at Point1.
    parameter r2.       // Orbit radius at Point2.
    parameter c.        // Chord Point1-Point2.
    parameter mu.       // Standard Gravitational Parameter of central body.

// Bisection Algorithm stopping criteria.
    local TolerancePct to 0.1.
    local tToleranceTSpan to t*TolerancePct/100.

    local a to 0.       // Semi-major axis.
    local s to          // Semi-perimeter.
      (r1+r2+c)/2.
    local amin to 0.    // Bisection minimum a.
    local amax to 0.    // Bisection maximum a.

    local finished to false.
    local tcalc to 0.

// Initial guess.
    set amin to s/2.
    set amax to 2*s.

// Adjust initial amax guess if it isn't high enough.
    set tcalc to CalcTransferTimeLamberts(r1,r2,c,amax,mu).
    until tcalc < t
      {
        set amax to amax*2.
        set tcalc to CalcTransferTimeLamberts(r1,r2,c,amax,mu).
      }

// Find the semi-major axis for the given transfer time.
    set finished to false.
    until finished
      {
        set a to (amax+amin)/2.
        set tcalc to CalcTransferTimeLamberts(r1,r2,c,a,mu).
        if tcalc > t
          set amin to a.
        else
          set amax to a.
        set finished to NearEqual(t:seconds,tcalc:seconds,ttoleranceTSpan:seconds).
      }
    return a.
  }

local function CalcTransferTimeLamberts
  {
// Calculate transfer time using Lambert's Equation.
// Notes:
//    - Uses the "modern formulation"? of Lambert's Equation
//      copied verbatim from various sources.
//    - Only works for elliptical orbit transfers ie not
//      parabolic or hyperbolic.
//    - The code is written as a series of steps to make it
//      easier to understand and debug.
//    - 
// Todo:
//    -

    parameter r1.       // Orbit radius at Point1.
    parameter r2.       // Orbit radius at Point2.
    parameter c.        // Chord Point1-Point2.
    parameter a.        // Semi-major axis.
    parameter mu.       // Standard Gravitational Parameter of central body.

// Semi-perimeter.
    local s to (r1+r2+c)/2.

// What I call the "alpha" and "beta" terms in the equation.
// I don't know why they break it down like this, except maybe
// to put it into a "form" similiar to Kepler's Equation.
    local AlphaDeg to 2*arcsin(sqrt(s/(2*a))).
    local AlphaRad to AlphaDeg*constant:DegToRad.
    local BetaDeg to 2*arcsin(sqrt((s-c)/(2*a))).
    local BetaRad to BetaDeg*constant:DegToRad.

// Transfer time.
    local t to
      sqrt(a^3/mu)*(AlphaRad-BetaRad-(sin(AlphaDeg)-sin(BetaDeg))).

    return timespan(0,0,0,0,t).
  }

local function CalcParabolicTransferTime
  {
// Calculate the parabolic transfer time.
// Notes:
//    - The parabolic solution defines the minimum transfer
//      time. For an elliptical orbit solution,
//      the transfer time has to be greater than this.
//    - Another way of looking at it is a parabolic
//      solution has an SMA value that approaches infinity.
//      Solutions close to the parabolic solution will
//      also have large SMA values.
//    -
// Todo:
//    -

    parameter r1.       // Orbit radius at Point1.
    parameter r2.       // Orbit radius at Point2.
    parameter c.        // Chord Point1-Point2.
    parameter mu.       // Standard Gravitational Parameter of central body.

// Semi-perimeter.
    local s to (r1+r2+c)/2.

    local tparabolic to
      (sqrt(2)/3)*sqrt(s^3/mu)*(1-((s-c)/s)^1.5).

    return timespan(0,0,0,0,tparabolic).
  }

local function CalcTransfervVec
  {
// Calculate the velocity of the transfer orbit at
// the departure point.
// Notes:
//    - This works because the departure(r1) and arrival(r2)
//      position vectors define the orbital plane for the transfer orbit.
//    - Once the velocity at the departure point is know, the vector for
//      maneuver can be calculated.
//    - The velocity at the arrival point can also be calculated using
//      a similiar equation.
//    - 
// Todo:
//    - 
//    -

    parameter r1Vec.
    parameter r2Vec.
    parameter a.
    parameter mu.

// Cord vector.
    local cVec to r2Vec-r1Vec.

// Cord.
    local c to cVec:mag.

// Semi-perimeter.
    local s to (r1Vec:mag+r2Vec:mag+c)/2.

// The same alpha and beta parameters used in
// Lambert's Equation.
    local AlphaDeg to 2*arcsin(sqrt(s/(2*a))).
    local BetaDeg to 2*arcsin(sqrt((s-c)/(2*a))).

// A and B are also parameters (I guess).
    local ACap to sqrt(mu/(4*a))*CalcCot(AlphaDeg/2).
    local BCap to sqrt(mu/(4*a))*CalcCot(BetaDeg/2).

    local TransfervVec to
      (BCap+ACap)*cVec:normalized+(BCap-ACap)*r1Vec:normalized.

    return TransfervVec.
  }

local function StartTransfer
  {
// Start the transfer at the departure time.
// Notes:
//    - 
// Todo:
//    - 

    local ThrottleSet to 0.
    local SteeringDir to 0.
    local ManeuverSecs to 0.
    local SteeringStartTStmp to 0.

    set ManeuverSecs to
      DeltavEstBurnTime
        (
          vFinalTransDv,
          ship:mass,
          ship:availablethrust,
          ISPVesselStage()
        ).

    set ManeuverStartTStmp to tFinalDepTStmp-ManeuverSecs/2.
    set SteeringStartTStmp to ManeuverStartTStmp-SteeringTSpan.
    MFDFunctions["DisplayManuever"](ManeuverSecs,vFinalTransDv).

    MFDFunctions["DisplayFlightStatus"]("Departure wait").
    DoSafeWait(SteeringStartTStmp,WarpType).

// Recalculate the delta-v vector for the maneuver as the origin and axes
// of the central body would have moved by now.
    set ManeuverVec to
      CalcTransfervVec
        (
          positionat(ship,tFinalDepTStmp)-ship:body:position,
          positionat(ArrivalOrbital,tFinalDepTStmp+tFinalTransTSpan)-ship:body:position,
          aFinalTrans,
          ship:body:mu
        )
      -velocityat(ship,tFinalDepTStmp):orbit.

// Diagnostic: Comment out when not required.
// Create a maneuver node to display the transfer orbit
// that results from the maneuver. The actual orbit should match closely
// after the maneuver burn.
//    local zzz to CreateNodeFromVec(ManeuverVec,tFinalDepTStmp).
//    add zzz.

    set SteeringDir to lookDirUp(ManeuverVec,ship:facing:topvector).
    lock steering to SteeringDir.
    lock throttle to Throttleset.

    MFDFunctions["DisplayFlightStatus"]("Steering").
    wait until timestamp() > ManeuverStartTStmp.
    MFDFunctions["DisplayFlightStatus"]("Transfer burn").
    set Throttleset to 1.
    wait until timestamp() > ManeuverStartTStmp+ManeuverSecs.
    set ThrottleSet to 0.
    MFDFunctions["DisplayFlightStatus"]("Transfering").
    set ManeuverStartTStmp to timestamp(0).
    MFDFunctions["DisplayManuever"](0,0).

// Wait to allow throttle down to complete.
// If this is not done, subsequent "on rails" time warps might
// fail due to phantom acceleration.
    wait 0.5.

    unlock throttle.
    unlock steering.
  }

local function HandleArrival
  {
// Handle the various situations that can occur at the
// end of the transfer orbit.
// Notes:
//    - The situations are:
//        - An intended encounter with the arrival SOI.
//        - An unintended encounter with a different SOI,
//          treat as a flyby.
//        - Missing the intended SOI, treat as a flyby.
//        - The arrival orbital is a ship, treat as a flyby.
//    -
// Todo:
//    - Add code to handle the close approach with a ship.
//    -

    local ArrivalTStmp to 0.
    local SOIEncounter to false.

    if ship:obt:transition = "ENCOUNTER"
      {
        set SOIEncounter to true.
        set ArrivalTStmp to timestamp()+ship:obt:eta:transition.
      }
    else
      set ArrivalTStmp to tFinalDepTStmp+tFinalTransTSpan.
    DoSafeWait(ArrivalTStmp,WarpType).

    if SOIEncounter
      {
// Ensure the transition to the SOI has occurred.
// The wait may have stopped just short of the SOI edge.
        wait until ship:obt:transition <> "ENCOUNTER".
        if ArrivalAction = "CAPTURE"
          and ship:body:name = ArrivalOrbital:name
          {
            if ship:obt:periapsis < SafeOrbitAlt
              DoAdjustPeManeuver().
            DoCaptureManeuver().
          }
        else
          DoFlybyManeuver().
      }
    else
      DoFlybyManeuver().
  }

local function DoAdjustPeManeuver
  {
// Do a course correction to increase the periapsis to a safe altitude.
// Notes:
//    - This course correction is a fudge to make the script work,
//      a better solution is needed.
//    - The encounter may be retrograde, and is treated the same as a prograde encounter.
//      The result will be a retrograde capture orbit???
//    -
// Todo:
//    - Compare a radial orbit adjustment to a prograde/retrograde
//      orbit adjustment.
//    - Treat a retrograde encounter as a special case, and force it into
//      a prograde encounter?
//    - 

    local tset to 0.
    local RadialOutVec to vcrs(ship:velocity:orbit,ShipObtNormalVec).
    local SteeringEndTStmp to 0.
    local BurnPID to pidLoop().

    MFDFunctions["DisplayFlightstatus"]("Steering").

    set SteeringEndTStmp to timestamp()+SteeringTSpan.
    lock steering to RadialOutVec.
    wait until timestamp() > SteeringEndTStmp.

    MFDFunctions["DisplayFlightstatus"]("Raise Pe burn").

// The gain of the PID controller is set relatively low
// as usually only a small delta-v from the edge of the SOI
// is required to adjust the periapsis. Tuning it was a bit
// of guesswork.
    set BurnPID:KP to 1/SafeOrbitMargin.
    set BurnPID:KI to 0.
    set BurnPID:KD to 0.
    set BurnPID:epsilon to 0.01.
    set BurnPID:setpoint to SafeOrbitAlt.
    set BurnPID:minoutput to 0.
    set BurnPID:maxoutput to 1.
    set tset to BurnPID:update(time:seconds,ship:orbit:periapsis).
    lock throttle to tset.
    until tset = 0 
      {
        set tset to BurnPID:update(time:seconds,ship:orbit:periapsis).
        wait 0.
      }
// Wait to allow throttle down to complete.
// If this is not done, subsequent "on rails" time warps might
// fail due to phantom acceleration.
    wait 0.5.
    unlock throttle.
    unlock steering.
  }

local function DoCaptureManeuver
  {
// Do the maneuver to put the ship in a capture orbit.
// Notes:
//    - The capture maneuver is done at the periapsis of the hyperbolic
//      orbit at arrival. The capture radius is the periapsis.
//    -
// Todo:
//    - 

    local ThrottleSet to 0.
    local SteeringDir to 0.
    local ManeuverSecs to 0.
    local ManeuverPointTStmp to 0.
    local SteeringStartTStmp to 0.
    local rCapture to 0.
    local vCapture to 0.
    local vDeltav to 0.

    set ManeuverPointTstmp to timestamp()+ship:obt:eta:periapsis.

    set rCapture to ship:obt:periapsis+ship:obt:body:radius.
    set vCapture to sqrt(ship:obt:body:mu/rCapture).
    set vDeltav to velocityat(ship,ManeuverPointTstmp):obt:mag-vCapture.
    set ManeuverSecs to
      DeltavEstBurnTime
        (
          vDeltav,
          ship:mass,
          ship:availablethrust,
          ISPVesselStage()
        ).
    set ManeuverStartTstmp to ManeuverPointTstmp-ManeuverSecs/2.
    set SteeringStartTStmp to ManeuverStartTStmp-SteeringTSpan.
    MFDFunctions["DisplayFlightStatus"]("Capture wait").
    MFDFunctions["DisplayManuever"](ManeuverSecs,vDeltav).

// Check to see if there is enough time to do the burn.
    if timestamp() > (ManeuverStartTstmp-SteeringDuration)
      {
        MFDFunctions["DisplayError"]("Not enough time for capture burn").
        print 0/0.
      }
    DoSafeWait(SteeringStartTStmp,WarpType).
    set ManeuverVec to -velocityat(ship,ManeuverPointTstmp):obt.
    set SteeringDir to lookdirup(ManeuverVec,ship:facing:topvector).
    lock steering to SteeringDir.
    lock throttle to ThrottleSet.
    MFDFunctions["DisplayFlightStatus"]("Steering").
    wait until timestamp() > ManeuverStartTStmp.
    MFDFunctions["DisplayFlightStatus"]("Capture burn").
    set ThrottleSet to 1.
    wait until timestamp() > ManeuverStartTStmp+ManeuverSecs.
    set ThrottleSet to 0.
    set ManeuverStartTStmp to timestamp(0).
    MFDFunctions["DisplayManuever"](0,0).
    unlock steering.
    unlock throttle.
  }

local function DoFlybyManeuver
  {
// Do a flyby.
// Notes:
//    - 
// Todo:
//    -

    MFDFunctions["DisplayFlightStatus"]("Flyby").
  }

local function SetMFD
  {
// Set the Multi-function Display.
// Notes:
//    -
// Todo:
//    -
    clearScreen.
    set terminal:width to 56+1.
//    set terminal:width to 100.
    set terminal:height to 22.
    MFDFunctions["DisplayLabels"]
      (ship:name,OrbitalName,SearchType).
    SetMFDRefreshTrigger().
  }

local function SetMFDRefreshTrigger
  {
// Refresh the Multi-function Display.
// Notes:
//		-
// Todo:
//		- Try to figure out how often this needs to run.
//    - It should be easy enough to add logic to skip a number of physics
//      ticks before a refresh is done if necessary.
    local RefreshInterval to 0.1.
    when (NextMFDRefreshTime < time:seconds)
    then
      {
        MFDFunctions["DisplayRefresh"]
         (
          ship:obt:apoapsis,
          ship:obt:periapsis,
          ship:obt:eccentricity,
          SearchStepSize,
          tDepTStmp,
          tTransTSpan,
          ManeuverStartTStmp,
          timestamp()
         ).
        set NextMFDRefreshTime to NextMFDRefreshTime+RefreshInterval.
        return MFDRefreshTriggerActive.
      }
  }

local function GetArrivalOrbital
  {
// Get the arrival orbital.
// Notes:
//    - If the name of the orbital is incorrect the
//      script will stop with a kOS error at this point.
//    -
// Todo:
//    -
    if bodyExists(OrbitalName)
      {
        set ArrivalOrbital to body(OrbitalName).
        set SafeOrbitAlt to ArrivalOrbital:atm:height+SafeOrbitMargin.
      }
    else
      {
        set ArrivalOrbital to vessel(OrbitalName).         
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
//    - Add the missing tests.
//    -

    if ArrivalAction <> "CAPTURE"
      and ArrivalAction <> "FLYBY"
      {
        MFDFunctions["DisplayError"]("Arrival Action is unknown").
        set FatalError to true.
      }
    else
    if SearchType <> "LOWESTDV"
      and SearchType <> "LOWESTTIME"
      {
        MFDFunctions["DisplayError"]("Search Type is unknown").
        set FatalError to true.
      }
    else
    if ship:body:name <> ArrivalOrbital:body:name
      {
        MFDFunctions["DisplayError"]("Departure and arrival must be in same SOI").
        set FatalError to true.
      }
    else
    if ArrivalAction = "CAPTURE"
      and not bodyExists(OrbitalName)
      {
        MFDFunctions["DisplayError"]("Arrival capture only valid for a moon or planet").
        set FatalError to true.
      }
    else
    if OrbitalName = ship:ShipName
      {
        MFDFunctions["DisplayError"]("Target orbital name same as this vessel").
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
//    -
// Todo:
//    -

// Set the triggers to fire once more only.
    set MFDRefreshTriggerActive to false.

// Ensure the triggers finish firing once more then stop.
    wait 0.

// Remove any global variables that might
// cause problems if they hang around.
    unset MFDFunctions.

// Unlock the throttle and steering controls
// used by the Player.
    unlock throttle.
    unlock steering.

// One more physics tick before finishing this script,
// just to be on the safe side.
    wait 0.
  }

local function CalcCot
  {
// Cotangent function input degrees.

    parameter angle.

//    local cotx to cos(angle)/sin(angle).
    local cotx to 1/tan(angle).

    return cotx. 
  }

local function CreateNodeFromVec
  {
// Create a maneuver node from a delta-v vector.
// Notes:
//    - This code was copied from the Internet.
//    -
// Todo:
//    - This function needs to be checked and added to the code library.
//    -
    PARAMETER vec.
    parameter n_time IS TIME:SECONDS.

    LOCAL s_pro IS VELOCITYAT(SHIP,n_time):ORBIT.
    LOCAL s_pos IS POSITIONAT(SHIP,n_time)-ship:BODY:POSITION.
    LOCAL s_nrm IS VCRS(s_pro,s_pos).
    LOCAL s_rad IS VCRS(s_nrm,s_pro).

    LOCAL pro IS VDOT(vec,s_pro:NORMALIZED).
    LOCAL nrm IS VDOT(vec,s_nrm:NORMALIZED).
    LOCAL rad IS VDOT(vec,s_rad:NORMALIZED).

    RETURN NODE(n_time, rad, nrm, pro).
  }

local function DoSafeWait
  {
// Wait until a point in time.
// Notes:
//    - Work in progress until I am happy it is indeed "safe" enough.
//      Once safe the function will be added to the function library.
//    - Waiting until a point in time is usually safer than waiting a
//      number of game seconds.
//    - The KSP Time Warp is a "4th Wall" function as far as
//      kOS is concerned. Time Warp runs independently of kOS and can
//      respond to user input. Time Warp is not well synchronised
//      with kOS.
//    - This function tries to allow for various factors that
//      can affect how well kOS and Time Warp run together.
//    -
// Todo
//    - Test, test and test some more.
//    - Allow a timing margin to avoid Time Warp undershoot and
//      overshoot?
//    -

    parameter WaitToTStmp.
    parameter WarpType.

    if WarpType = "NOWARP"
      wait until timestamp() >= WaitToTStmp.
    else
    if WarpType = "PHYSICS"
      wait until timestamp() >= WaitToTStmp.
    else
    if WarpType = "RAILS"
      {
// On-rails time warping only runs a limited game simulation,
// the ship is unpacked, some system values become undefined etc.
// The Player can also change the warp rate or stop the time warp completely.
// The "wait until" tries to get the time warp and the kOS script back into
// sync without issues, at the expense of a possible overshoot.
// Check the KSP log to see time warp undershoot/overshoot warnings.
        set kuniverse:timewarp:mode to WarpType.
        kuniverse:timewarp:warpTo(WaitToTStmp:seconds).
        wait until kuniverse:timewarp:warp = 0 and ship:unpacked.

// This "wait until" runs indepently of the time warp.
// This wait will still work even if the time warp is modified by
// Player input.
// If the time warp stops early (undershoots) the wait duration will
// still be correct. If the time warp stops late (overshoots) then
// the wait duration will be longer than expected.
        wait until timestamp() > WaitToTStmp.
      }
    else
      print 0/0.  // Unknown WarpType value so terminate the script.
  }