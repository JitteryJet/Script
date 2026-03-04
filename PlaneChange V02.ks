// Name: PlaneChange
// Author: JitteryJet
// Version: V02
// kOS Version: 1.3.2.0
// KSP Version: 1.13.2
// Description:
//    Change vessel orbital inclination or
//    match planes with another orbital in the SOI.
//
// Notes:
//    Features:
//      - KSP Maneuver Nodes are not used.
//
//    Out of Fuel:
//      - Out of Fuel is ignored. If there is not enough fuel, results will be
//        unpredictable.
//
//    Vessel Design:
//      - The vessel is assumed to have enough steering to allow the kOS Steering Manager to
//        maneuver the vessel.
//
//    Misc Notes:
//      - I use the term "match" instead of "target" to avoid confusion
//        with bound variable names.
//
// Todo:
//    - Test a target body outside the SOI body.
//    - Add parameter error checking.
//    - Add SOI body as a special case, the plane is the equatorial plane.
//
// Update History:
//    24/07/2020 V01  - Created.
//    23/12/2021 V02  - WIP.
//                    - Fixed up AN DN swap.
//                    - Declare local functions LOCAL to ensure they are
//                      not accidentally called from other scripts. The
//                      default scope for a function is GLOBAL.
//                    - Add flags to remove triggers when this script ends.
//                    - Parameter changes to the OrbitalBurn function.
//                    - Tested KSP 1.12.3.
//                    -
@lazyglobal off.
// Parameter descriptions.
//    EquatorialInclination   New inclination for an inclination change.            
//    MatchName               Blank for an inclination change or
//                            name of a body to match planes with.
//    NodeName                Node to use for plane change "AN" or "DN".
//    SteeringDuration        Time to allow the vessel to steer to the burn
//                            direction.                   
//	  WarpType						    "PHYSICS","RAILS" or "NOWARP".

parameter EquatorialInclination to 0.
parameter MatchName to "".
parameter NodeName to "AN".
parameter SteeringDuration to 60.
parameter WarpType to "NOWARP".

// Load in library functions.
runoncepath("MiscFunctions V04").
runoncepath("PlaneChangeMFD V03").
runoncepath("Delta-vFunctions V03").
runoncepath("OrbitFunctions V03").
runoncepath("OrbitBurnFunctions V03").

// Other launch control values that can be tuned.

// Top-level variable declarations.
local NextMFDRefreshTime to time:seconds.
local ManeuverPoint to 0.
local BurnStartTime to 0.
local ManeuverPointTS to 0.
local BurnDuration to 0.
local BurnDeltavVec to 0.
local ANPosition to 0.
local DNPosition to 0.
local InclinationChange to 0.
local MOrbit to 0.
local MFDRefreshTriggerActive to true.
local StagingTriggerActive to true.

// Other initialisations.
sas off.
lock throttle to 0.
SetStagingTrigger().

// Main program.
CalcLineOfNodes().
SetMFD().
SelectManeuverPoint().
CalcBurn().
WaitForBurnStart().
PlaneChangeManeuver().
RemoveLocksAndTriggers().

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
    if MatchName = ""
      PlaneChangeMFD["DisplayLabels"]
        (ship:name,ship:body:name,EquatorialInclination).
    else
      PlaneChangeMFD["DisplayLabels"]
        (ship:name,MatchName,MOrbit:inclination).
    SetMFDRefreshTrigger().
  }

local function SelectManeuverPoint
  {
// Select node for the burn.
// Notes:
//    - 
// Todo:
//    -
    if NodeName = "AN"
      set ManeuverPoint to ANPosition.
    else
    if NodeName = "DN"
      set ManeuverPoint to DNPosition.
    else
      print 0/0. 
  }

local function CalcBurn
  {
// Calculate the burn details.
// Notes:
//    -
// Todo:
//    -
    local EnoughTime to false.
    local TimeToManeuverPoint to
      TimeToOrbitPosition
        (
          ship:orbit:trueanomaly,
          ManeuverPoint,
          ship:orbit:eccentricity,
          ship:orbit:period
        ).
    set ManeuverPointTS to time()+TimeToManeuverPoint.
    set BurnDeltavVec to
      CalcPlaneChangeDeltavVec
        (
          positionat(ship,ManeuverPointTS)-ship:body:position,
          velocityat(ship,ManeuverPointTS):orbit,
          InclinationChange,
          NodeName
        ).
    set BurnDuration to
      DeltavEstBurnTime
        (
          BurnDeltavVec:mag,
          ship:mass,
          ship:availablethrust,
          ISPVesselStage()
        ).
    until EnoughTime
      {
        if TimeToManeuverPoint < SteeringDuration+BurnDuration
          {
            set TimeToManeuverPoint to
              TimeToManeuverPoint+ship:orbit:period.
            set ManeuverPointTS to time()+TimeToManeuverPoint.
            wait 0.
          }
        else
          set EnoughTime to true.
      }
    set BurnStartTime to ManeuverPointTS:seconds-BurnDuration/2.
    PlaneChangeMFD["DisplayManuever"](BurnDuration,BurnDeltavVec:mag).
  }

local function WaitForBurnStart
  {
// Wait until the start of the burn.
// Notes:
//    - Wait until burn start is coded as a loop instead of
//      a wait command to get around RAILS time warping
//      affecting the wait <duration> command.
//      This does not occur if PHYSICS time warping is used.
//      It's probably related to the game "reloading" when
//      the RAIL time warping completes.
// Todo:
//    -
    PlaneChangeMFD["DisplayFlightStatus"]("Wait for "+NodeName).
    if WarpType <> "NOWARP"
      {
        WarpToTime(BurnStartTime-SteeringDuration,WarpType).
      }
    until time:seconds > BurnStartTime-SteeringDuration
      wait 0.
// Calculate the burn vector again because velocityat and positionat
// are sensitive to any KSP co-ordinate shifts.
    set BurnDeltavVec to
      CalcPlaneChangeDeltavVec
        (
          positionat(ship,ManeuverPointTS)-ship:body:position,
          velocityat(ship,ManeuverPointTS):orbit,
          InclinationChange,
          NodeName
        ).
    lock steering to lookDirUp(BurnDeltavVec,ship:facing:topvector).
    wait SteeringDuration.
  }

local function PlaneChangeManeuver
  {
// Plane Change maneuver burn.
// Notes:
//    -
// Todo:
//    -
    PlaneChangeMFD["DisplayFlightStatus"]("Plane Change").
    OrbitalBurn(BurnDeltavVec,BurnDuration).
    PlaneChangeMFD["DisplayFlightStatus"]("Plane Chg fin").
  }

local function SetStagingTrigger
  {
// Stage automatically when the fuel in the stage runs out.
// Stop auto staging if the last stage has been staged.
// Notes:
//		-
// Todo:
//		- This staging does not handle sepratrons correctly - they count as solid
//			fuel.
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

local function SetMFDRefreshTrigger
  {
// Refresh the Multi-function Display.
// Notes:
//		- Experimental. I have no idea what the physics tick cost will be.
// Todo:
//		- Try to figure out how often this needs to run.
//    - It should be easy enough to add logic to skip a number of physics
//      ticks before a refresh is done if necessary.
    local RefreshInterval to 0.2.
    when (NextMFDRefreshTime < time:seconds)
    then
      {
        PlaneChangeMFD["DisplayRefresh"]
         (
          ship:apoapsis,
          ship:periapsis,
          ship:orbit:inclination,
          BurnStartTime,
          Time:Seconds
         ).
        set NextMFDRefreshTime to NextMFDRefreshTime+RefreshInterval.
        return MFDRefreshTriggerActive.
      }
  }

local function GetMatchOrbit
  {
// Get the orbit to match planes with.
// Notes:
//    - Body names take precedence over vessel names.
// Todo:
//    -
    if bodyExists(MatchName)
      {
        set MOrbit to body(MatchName):orbit.
      }
    else
      {
        set MOrbit to vessel(Matchname):orbit.         
      }
  }

local function CalcLineOfNodes
  {
// Calculate the line of nodes data.
// Notes:
//    - The Line Of Nodes is where the two orbital planes
//      of interest intersect.
//      For a orbital inclination change the planes are the
//      plane of the vessel's orbit and the equatorial
//      reference plane.
//      For a match plane the planes are the plane of the
//      vessel's orbit and the plane of the object to
//      match with.
// Todo:
//    -

    if MatchName = ""
      {
        set ANPosition to 360-ship:orbit:argumentofperiapsis.
        set InclinationChange to EquatorialInclination-ship:orbit:inclination.
      }
    else
      {
        GetMatchOrbit().
        local SOIRawPositionVec to ship:orbit:position-ship:body:position.
        local SOIRawMPositionVec to MOrbit:position-ship:body:position.

        local OrbitSAMVec to CalcSAMVec(SOIRawPositionVec,ship:orbit:velocity:orbit).
        local MOrbitSAMVec to CalcSAMVec(SOIRawMPositionVec,MOrbit:Velocity:Orbit).

        local OrbitEccentricityVec to CalcEccentricityVec(SOIRawPositionVec,ship:orbit:velocity:orbit,ship:body:mu).

        local ANPositionVec to CalcAscendingNodeVec(OrbitSAMVec,MOrbitSAMVec).

        set ANPosition to CalcTrueAnomalyFromVec(ANPositionVec,OrbitEccentricityVec,OrbitSAMVec).
        set InclinationChange to -CalcRelativeInclination(OrbitSAMVec,MOrbitSAMVec).

//        DrawSAMVector(SOIRawPositionVec,ship:orbit:velocity:orbit,"H Ship").
//        DrawSAMVector(SOIRawMPositionVec,Morbit:velocity:orbit,"H Minmus").
//        DrawEccentricityVector(OrbitEccentricityVec).
//        DrawLineOfNodes(ANPositionVec).
      }
    set DNPosition to mod(ANPosition+180,360).
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