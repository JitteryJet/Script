// Name: TransferSimpleLambertSolver
// Author: JitteryJet
// Version: V02
// kOS Version: 1.5.1.0
// KSP Version: 1.12.5
// Description:
//    Transfer a ship in orbit to a target orbital
//    in the same SOI by using a Simple Lambert Solver.
//
// Assumptions:
//    - No staging is required.
//    - The orbital is a body or ship.
//    - The target orbital is in the same SOI as the ship.
//    - The departure and arrival orbits are prograde (anticlockwise)
//      defined by north being up. The code MIGHT work with 
//      retrograde orbits but is untested.
//    - 
//
// Notes:
//    - This script finds a transfer orbit by using a Simple Lambert Solver.
//
//    - These transfers are handled:
//
//        - Transfer to the target body with a flyby or a capture.
//        - Transfer to the target ship with a flyby.
//
//    - Lots of orbits to keep track of:
//        Departure             - The orbit of the ship.
//        Arrival               - Orbit of the target body or ship.
//        Capture               - The orbit of the ship after capture at the arrival body.
//        Hyperbolic Arrival    - The orbit of the ship after encountering the SOI of the arrival body.
//        Transfer              - Transfer orbit to the target body or ship.      
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
// Todo:
//    - Add staging.
//    - Add code to terminate the program if another body interfers
//      with the transfer (yes I am looking at you, Mun).
//    - Optimise run time by reusing the Alpha and Beta angle values
//      in Lambert's Equation instead of recalculating them.
//      Benchmark change in performance to ensure it is worth doing.
//    - Have another look at how a safe periapsis height is guaranteed
//      at the end of the transfer orbit. Periapsis as a parameter?
//      Ignore Lambert Solver solutions where the ship will crash
//      into the arrival body? Formula to calculate the velocity change
//      required to adjust the periapsis during a hyperbolic encounter? 
//    -
//
// Update History:
//    15/07/2022 V01  - Created.
//    27/03/2026 V02  - WIP.
//                    - Updates for the Artemis 2 simulation.
//                    - Changed Delta-vFunctions V03 to V05.
//                    - Changed MiscFunctions V04 to V06.
//                    - Replaced the local version of DoSafeWait with the
//                      version in the MiscFunctions library.
//                    - Added LambertSolverFunctions V03.
//                    - Replaced inline Lambert Solver Function code with
//                      Lambert Solver Function library calls.
//                    - Replaced orbit search step time parameter with number of steps.
//                    - Added ASAP search type.
//                    - Removed warping to the target SOI from flyby arrival action.
//                    - Added target orbital offset duration.
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
//    SearchType              Search type for departure time and transfer time:
//                              "LOWESTDV"      - Lowest transfer delta-v
//                              "LOWESTTIME"    - Lowest transfer time
//                              "NOW"           - Lowest transfer delta-v from current departure time
//                                                plus one step (to allow for search time).
//    OrbitSearchSteps        Number of steps to use when searching the orbits.
//    OrbitOffsetDuration     Leading (-ve) or trailing (+ve) target position offset (s).
//                            This is to allow a flyby to miss the target orbital.
//    SteeringDuration        Time to allow the vessel to steer to the burn
//                            attitude for the maneuver (s).                            
//	  WarpType	  					  "PHYSICS","RAILS" or "NOWARP".
//    ShowArrows              "SHOW" or "NOSHOW".
//    

parameter OrbitalName to "".
parameter ArrivalAction to "CAPTURE".
parameter SearchType to "LOWESTDV".
parameter OrbitSearchSteps to 100.
parameter OrbitOffsetDuration to 0.0.
parameter SteeringDuration to 60.0.
parameter WarpType to "RAILS".
parameter ShowArrows to "NOSHOW".

// Adjust parameters if required.
set OrbitSearchSteps to floor(OrbitSearchSteps).

// Load in library functions.
runoncepath("TransferSimpleLambertSolverMFD V02").
runoncepath("Delta-vFunctions V05").
runoncepath("OrbitFunctions V04").
runoncepath("LambertSolverFunctions V03").

local NextMFDRefreshTime to timestamp(0.0).
local ArrivalOrbital to ship.
local ManeuverStartTStmp to timestamp(0.0).
local ManeuverVec to 0.
local FatalError to false.
local MFDRefreshTriggerActive to true.
local MFDRefreshInterval to 0.1.
local VeryBigNumber to 3.402823E+38.
local tSteeringTSpan to timespan(0.0,0.0,0.0,0.0,SteeringDuration).
local tOrbitOffsetTSpan to timespan(0.0,0.0,0.0,0.0,OrbitOffsetDuration).

// Minimum height above the atmosphere (or sea level for airless)
// where an orbit is considered safe.
local SafeOrbitMargin to 10*1000.
local SafeOrbitAlt to 0.

// Warning: Orbital State Vector invariants should be recalculated
// when used to ensure the values are up to date, the origins and
// axes move over time.
local lock ShipPositionVec to ship:position-ship:body:position.
local lock ShipObtNormalVec to vcrs(ShipPositionVec,ship:velocity:obt).

local tDepTStmp to timestamp(0.0).
local tTransTSpan to timespan(0.0).
local aFinalTrans to 0.
local vFinalTransDv to 999999.
local tFinalTransTSpan to timespan(99999.0,0.0).
local tFinalDepTStmp to timestamp().
local FinalShortWayOrbit to false.

// Log file for debugging.
local LogFilename to kuniverse:realtime:tostring+".txt".

local DepartureArrow to
  vecdraw(V(0,0,0),V(0,0,0),red,"Departure Position",1,false,0.1,true,true).
local ArrivalArrow to
  vecdraw(V(0,0,0),V(0,0,0),green,"Arrival Position",1,false,0.1,true,true).

sas off.
set ship:control:mainthrottle to 0.
clearvecdraws().
GetArrivalOrbital().
SetMFD().
CheckForErrorsAndWarnings().
if not FatalError
  {
    SearchForTransfer().
    DoTransfer().
    HandleArrival().
  }
MFDFunctions["DisplayFlightStatus"]("Finished").
RemoveLocksAndTriggers().

local function SearchForTransfer
  {
// Search for a transfer orbit.
// Notes:
//    - Uses a Lambert Solver to generate candidate transfer orbits
//      based on departure times and transfer times.
//    - The orbits are filtered based on various criteria.
//    -
// Todo:
//    - Think some more about how far into the future to search for
//      solutions.
//    -

    MFDFunctions["DisplayFlightStatus"]("Solution search").

    local tDepStepTSpan to timespan(0.0,0.0,0.0,0.0,ship:obt:period/OrbitSearchSteps).
    local tArrStepTSpan to timespan(0.0,0.0,0.0,0.0,ArrivalOrbital:obt:period/OrbitSearchSteps).

    local r1 to 0.                          // Orbit radius of Point1.
    local r2 to 0.                          // Orbit radius of Point2.
    local c to 0.                           // Chord Point1-Point2.
    local mu to 0.                          // Standard Gravitational Parameter
    local aTrans to 0.                      // SMA of transfer orbit.
    local tMinTransTSpan to timespan(0.0).  // Minimum transfer time (TOF). Defines the parabolic solution.
    local tShortWayMaxTSpan to              // Short Way maxiumum transfer time.
      timespan(0.0).
    local aMinSOETrans to 0.                // Minimum energy transfer semi-major axis.
    local vDeltaVec to v(0,0,0).
    local TransferAng to 0.0.               // Transfer orbit angle.
    local ShortWayOrbit to false.           // Short Way orbit or Long Way orbit.

    local r1Vec to v(0,0,0).
    local r2Vec to v(0,0,0).
    local FinishDepLoop to false.

    set mu to ship:body:mu.
    if ShowArrows = "SHOW"
      {
        set DepartureArrow:show to true.
        set ArrivalArrow:show to true.
      }

    set tDepTStmp to timestamp()+tDepStepTSpan.
    from {local DepStep to 1.}
    until DepStep = OrbitSearchSteps or FinishDepLoop
    step
      {
        set DepStep to DepStep+1.
        set tDepTStmp to tDepTStmp+tDepStepTSpan.
      }
    do
      {
        set tTransTSpan to timespan(0.0).
        from {local ArrStep to 1.}
        until ArrStep > OrbitSearchSteps
        step
          {
            set ArrStep to ArrStep+1.
            set tTransTSpan to tTransTSpan+tArrStepTSpan.
          }
        do
          { 
            if tDepTStmp < timestamp()
              {
                MFDFunctions["DisplayError"]("Departure in the past. Transfer orbit search is too slow.").
                print 0/0.
              }
            set r1Vec to positionat(ship,tDepTStmp)-ship:body:position.
            set r2Vec to
              positionat(ArrivalOrbital,tDepTStmp+tTransTSpan+tOrbitOffsetTSpan)-ship:body:position.
            set r1 to r1Vec:mag.
            set r2 to r2Vec:mag.
            set c to (r2Vec-r1Vec):mag.
            set TransferAng to CalcAngleBetweenPositionVecs(r1Vec,r2Vec).
            set aMinSOETrans to (r1+r2+c)/4.
            set tMinTransTSpan to CalcParabolicTransferTimeLambert(r1,r2,c,mu,TransferAng).
            set tShortWayMaxTSpan to
                CalcTransferTimeLambert(r1,r2,c,aMinSOETrans,mu,TransferAng,true).
            if tTransTSpan < tShortWayMaxTSpan
              set ShortWayOrbit to true.
            else
              set ShortWayOrbit to false.
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
                  {
                    if tTransTSpan < tFinalTransTSpan
                      {
                        set tFinalDepTStmp to tDepTStmp.
                        set tFinalTransTSpan to tTransTSpan.
                        set aFinalTrans to
                          CalcSMALambert(tFinalTransTSpan,r1,r2,c,mu,TransferAng).
                        set vDeltaVec to
                          CalcTransferDepVelLambertVec
                            (r1Vec,r2Vec,aFinalTrans,mu,TransferAng,ShortWayOrbit)
                              -velocityat(ship,tDepTStmp):orbit.
                        set vFinalTransDv to vDeltaVec:mag.
                        set FinalShortWayOrbit to ShortWayOrbit.
                      }
                  }
              }
            else
            if SearchType = "LOWESTDV"
              {
                if tTransTSpan > tMinTransTSpan
                  {
                    set aTrans to CalcSMALambert(tTransTSpan,r1,r2,c,mu,TransferAng).
                    set vDeltaVec to
                      CalcTransferDepVelLambertVec
                        (r1Vec,r2Vec,aTrans,mu,TransferAng,ShortWayOrbit)-velocityat(ship,tDepTStmp):orbit.
                    if vDeltaVec:mag < vFinalTransDv
                      {
                        set vFinalTransDv to vDeltaVec:mag.
                        set aFinalTrans to aTrans.
                        set tFinalDepTStmp to tDepTStmp.
                        set tFinalTransTSpan to tTransTSpan.
                        set FinalShortWayOrbit to ShortWayOrbit.
                      }
                  }
              }
            if SearchType = "NOW"
              {
                if tTransTSpan > tMinTransTSpan
                  {
                    set aTrans to CalcSMALambert(tTransTSpan,r1,r2,c,mu,TransferAng).
                    set vDeltaVec to
                      CalcTransferDepVelLambertVec
                        (r1Vec,r2Vec,aTrans,mu,TransferAng,ShortWayOrbit)-velocityat(ship,tDepTStmp):orbit.
                    if vDeltaVec:mag < vFinalTransDv
                      {
                        set vFinalTransDv to vDeltaVec:mag.
                        set aFinalTrans to aTrans.
                        set tFinalDepTStmp to tDepTStmp.
                        set tFinalTransTSpan to tTransTSpan.
                        set FinalShortWayOrbit to ShortWayOrbit.
                      }
                    set FinishDepLoop to true.
                  }
              }
          }
      }
    MFDFunctions["DisplaySearchResults"]
      (
        tFinalDepTStmp,
        tFinalTransTSpan,
        aFinalTrans,
        vFinalTransDv
      ).
    set DepartureArrow:show to false.
    set ArrivalArrow:show to false.
  }

local function DoTransfer
  {
// Do the transfer at the departure time.
// Notes:
//    - 
// Todo:
//    - 

    local ThrottleSet to 0.
    local SteeringDir to 0.
    local ManeuverSecs to 0.
    local SteeringStartTStmp to 0.
    local r1Vec to v(0,0,0).
    local r2Vec to v(0,0,0).
    local TransferAng to 0.0.

    set ManeuverSecs to
      DeltavEstBurnTime
        (
          vFinalTransDv,
          ship:mass,
          ship:availablethrust,
          ISPVesselStage(0)
        ).

    set ManeuverStartTStmp to tFinalDepTStmp-ManeuverSecs/2.
    set SteeringStartTStmp to ManeuverStartTStmp-tSteeringTSpan.
    MFDFunctions["DisplayManuever"](ManeuverSecs,vFinalTransDv).

    MFDFunctions["DisplayFlightStatus"]("Departure wait").
    DoSafeWait(SteeringStartTStmp,WarpType).

    set r1Vec to positionat(ship,tFinalDepTStmp)-ship:body:position.
    set r2Vec to
      positionat(ArrivalOrbital,tFinalDepTStmp+tFinalTransTSpan+tOrbitOffsetTSpan)-ship:body:position.
    set TransferAng to CalcAngleBetweenPositionVecs(r1Vec,r2Vec).
    set ManeuverVec to
      CalcTransferDepVelLambertVec
        (
          r1Vec,
          r2Vec,
          aFinalTrans,
          ship:body:mu,
          TransferAng,
          FinalShortWayOrbit
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
    set ManeuverStartTStmp to timestamp(0.0).
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
    
    if SOIEncounter
      {
        if ArrivalAction = "CAPTURE"
          and ship:body:name = ArrivalOrbital:name
          {
            DoSafeWait(ArrivalTStmp,WarpType).
            wait until ship:obt:transition <> "ENCOUNTER".
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

    set SteeringEndTStmp to timestamp()+tSteeringTSpan.
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
          ISPVesselStage(0)
        ).
    set ManeuverStartTstmp to ManeuverPointTstmp-ManeuverSecs/2.
    set SteeringStartTStmp to ManeuverStartTStmp-tSteeringTSpan.
    MFDFunctions["DisplayFlightStatus"]("Capture wait").
    MFDFunctions["DisplayManuever"](ManeuverSecs,vDeltav).

// Check to see if there is enough time to do the burn.
    if timestamp() > (ManeuverStartTstmp-tSteeringTSpan)
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
    set NextMFDRefreshTime to timestamp():seconds.
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
    when (NextMFDRefreshTime < timestamp():seconds)
    then
      {
        MFDFunctions["DisplayRefresh"]
         (
          ship:obt:apoapsis,
          ship:obt:periapsis,
          ship:obt:eccentricity,
          OrbitSearchSteps,
          tDepTStmp,
          tTransTSpan,
          ManeuverStartTStmp,
          timestamp()
         ).
        set NextMFDRefreshTime to NextMFDRefreshTime+MFDRefreshInterval.
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
      and SearchType <> "NOW"
      {
        MFDFunctions["DisplayError"]("Search Type is unknown").
        set FatalError to true.
      }
    else
    if ship:body:name <> ArrivalOrbital:body:name
      {
        MFDFunctions["DisplayError"]("Target orbital must be in same SOI").
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
    if OrbitSearchSteps < 1
      {
        MFDFunctions["DisplayError"]("Orbital search steps must be 0 or more").
        set FatalError to true.
      }
  }

local function RemoveLocksAndTriggers
  {
// Remove locks and triggers.
// Notes:
//    - Guarantee unneeded locks, triggers and varibles are removed before
//      any following script is run. THROTTLE, STEERING and
//      triggers are in the global scope and will keep processing
//      until control is returned back to the terminal program -
//      this is relevant if this script is ran using
//      RUNPATH from another script before exiting to the
//      terminal program.
//    -
// Todo:
//    -

// Set the MFD refresh trigger to refresh the display once
// more and then remove the trigger from the program.
    set MFDRefreshTriggerActive to false.
    wait MFDRefreshInterval*2.

// Remove any global variables that might
// cause problems if they hang around.
    unset MFDFunctions.

// Unlock the throttle and steering controls.
    unlock throttle.
    unlock steering.

// One more physics tick before finishing this script,
// just to be on the safe side.
    wait 0.
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