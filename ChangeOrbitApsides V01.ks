// Name: ChangeOrbitApsides
// Author: JitteryJet
// Version: V01
// kOS Version: 1.5.1.0
// KSP Version: 1.12.5
// Description:
//    Change the apsides of the orbit.
//
// Assumptions:
//    - The engines are active and the stage contains
//      enough fuel to do the maneuver. 
//
// Notes:
//    - The script does not autostage.
//
// Todo:
//    - Add other adjustments when required.
//    - Add parameter checks.
//    - Consider changing the circularisation.
//      It takes too long to complete.
//    - Retest circularization with and without time warping.
//
// Update History:
//    02/01/2026 V01  - WIP.
//                    - Created.
//                    - 
@lazyglobal off.
// Parameter descriptions.
//    ChangeName              "CIRCULARIZE","CHANGEPE","CHANGEAP".
//    ApsisAltkm              Apsis altitude (km).
//    SteeringDuration        Duration of the steering required for the
//                            apside change maneuver (s).               
//	  WarpType	  					  "PHYSICS","RAILS" or "NOWARP".

parameter ChangeName to "".
parameter ApsisAltkm to 100.
parameter SteeringDuration to 60.0.
parameter WarpType to "NOWARP".

// Load in library functions.
runoncepath("ChangeOrbitApsidesMFD V01").
runoncepath("Delta-vFunctions V05").
runoncepath("MiscFunctions V06").

local ApsisAlt to ApsisAltkm*1000.
local NextMFDRefreshSecs to timestamp():seconds.
local BurnStartTStmp to timestamp(0.0).
local FatalError to false.
local MFDRefreshTriggerActive to true.

// This PID Loop is used to control thrust overshoot.
// These values might have to be adjusted by trial and error.
// A KP value of 1/10000 roughly gives a throttle ramp down during the
// last 10 kilometers of adjustment.
// A non-zero epsilon (deadband) value cuts the throttle when really low
// to allow the ramp down to complete more quickly.
local PLoop to PIDLoop().
set PLoop:KP to 1/10000.
set PLoop:KI to 0.
set PLoop:KD to 0.
set PLoop:epsilon to 0.01.

// Other initialisations.
sas off.
set ship:control:mainthrottle to 0.
lock throttle to 0.

SetMFD().
CheckForErrorsAndWarnings().
if not FatalError
  {
    SetMFDRefreshTrigger().
    if ChangeName="CIRCULARIZE"
      CircularizationBurn().
    else
    if ChangeName="CHANGEPE"
      ChangePeBurn().
    else
    if ChangeName="CHANGEAP"
      ChangeApBurn().
    else
      print 0/0.  // Terminate program.
  }

//wait until false.

RemoveLocksAndTriggers().

local function CircularizationBurn
  {
// Do a burn to circularize the orbit.
// Notes:
//    - Circularization in this context means raise the periapsis
//      to the same orbital altitude as the apoapsis.
// Todo:
//    -

    local tset to 0.
    PLoop:reset().

    local r1 to ship:periapsis+ship:body:radius.
    local r2 to ship:apoapsis+ship:body:radius.

    local BurnDeltav to CalcHohmannCircularizationDeltav(r1,r2,ship:body:mu).

    local BurnDuration to
      abs(DeltavEstBurnTime
        (
          BurnDeltav,
          ship:mass,
          ship:availablethrust,
          ISPVesselStage(0)
        )).

    local ManeuverPointTStmp to timestamp()+eta:apoapsis.

    set BurnStartTStmp to ManeuverPointTStmp-BurnDuration/2.

    ChangeOrbitApsidesMFD["DisplayManeuver"](BurnDuration,BurnDeltav).
    ChangeOrbitApsidesMFD["DisplayFlightStatus"]("Apoapsis wait").

    local SteeringVec to velocityat(ship,ManeuverPointTStmp):orbit.
    local SteeringDir to lookdirup(SteeringVec,ship:facing:topvector).
    DoSafeWait(BurnStartTStmp-SteeringDuration,WarpType).
    ChangeOrbitApsidesMFD["DisplayFlightStatus"]("Steering").
    lock steering to SteeringDir.
    wait SteeringDuration.
    ChangeOrbitApsidesMFD["DisplayFlightStatus"]("Circ burn").
    set PLoop:setpoint to r2.
    set PLoop:minoutput to 0.
    set PLoop:maxoutput to 1.
    set tset to PLoop:update(time:seconds,ship:orbit:semimajoraxis).
    lock throttle to tset.
    until tset = 0 
      {
        set tset to PLoop:update(time:seconds,ship:orbit:semimajoraxis).
        wait 0.
      }
    ChangeOrbitApsidesMFD["DisplayFlightStatus"]("Finished").
    lock throttle to 0.
  }

local function ChangePeBurn
  {
// Do a burn at the apoapsis to change the altitude of the periapsis.
// Notes:
//    -
// Todo:
//    -

    local ManeuverPointTStmp to timestamp()+eta:apoapsis.
    local r1 to ship:apoapsis+ship:body:radius.
    local r2 to ApsisAlt+ship:body:radius.
    local a to (r1+r2)/2.
    local vel to velocityAt(ship,ManeuverPointTStmp):orbit:mag.
    local SteeringVec to v(0,0,0).

    local BurnDeltav to
      CalcChangeEllipticalOrbitDeltaV
        (
          vel,
          r1,
          a,
          ship:body:mu
        ).

    local BurnDuration to
      abs(DeltavEstBurnTime
        (
          BurnDeltav,
          ship:mass,
          ship:availablethrust,
          ISPVesselStage(0)
        )).

    set BurnStartTStmp to ManeuverPointTStmp-BurnDuration/2.

    ChangeOrbitApsidesMFD["DisplayManeuver"](BurnDuration,BurnDeltav).
    ChangeOrbitApsidesMFD["DisplayFlightStatus"]("Apoapsis wait").

    if ship:orbit:periapsis < ApsisAlt
      set SteeringVec to velocityat(ship,ManeuverPointTStmp):orbit.
    else
      set SteeringVec to -velocityat(ship,ManeuverPointTStmp):orbit.
    local SteeringDir to lookdirup(SteeringVec,ship:facing:topvector).
    DoSafeWait(BurnStartTStmp-SteeringDuration,WarpType).
    ChangeOrbitApsidesMFD["DisplayFlightStatus"]("Steering").
    lock steering to SteeringDir.
// Do not use "wait SteeringDuration", it gives strange results
// if RAILS time warping is used.
    wait until timestamp() > BurnStartTStmp.
    ChangeOrbitApsidesMFD["DisplayFlightStatus"]("Apoapsis burn").
    lock throttle to 1.
    wait BurnDuration.
    ChangeOrbitApsidesMFD["DisplayFlightStatus"]("Finished").
    lock throttle to 0.
  }

local function ChangeApBurn
  {
// Do a burn at the periapsis to change the altitude of the apoapsis.
// Notes:
//    -
// Todo:
//    -

    local ManeuverPointTStmp to timestamp()+eta:periapsis.
    local r1 to ship:periapsis+ship:body:radius.
    local r2 to ApsisAlt+ship:body:radius.
    local a to (r1+r2)/2.
    local vel to velocityAt(ship,ManeuverPointTStmp):orbit:mag.
    local SteeringVec to v(0,0,0).

    local BurnDeltav to
      CalcChangeEllipticalOrbitDeltaV
        (
          vel,
          r1,
          a,
          ship:body:mu
        ).

    local BurnDuration to
      abs(DeltavEstBurnTime
        (
          BurnDeltav,
          ship:mass,
          ship:availablethrust,
          ISPVesselStage(0)
        )).

    set BurnStartTStmp to ManeuverPointTStmp-BurnDuration/2.

    ChangeOrbitApsidesMFD["DisplayManeuver"](BurnDuration,BurnDeltav).
    ChangeOrbitApsidesMFD["DisplayFlightStatus"]("Periapsis wait").

    if ship:orbit:apoapsis < ApsisAlt
      set SteeringVec to velocityat(ship,ManeuverPointTStmp):orbit.
    else
      set SteeringVec to -velocityat(ship,ManeuverPointTStmp):orbit.
    local SteeringDir to lookdirup(SteeringVec,ship:facing:topvector).
    DoSafeWait(BurnStartTStmp-SteeringDuration,WarpType).
    ChangeOrbitApsidesMFD["DisplayFlightStatus"]("Steering").
    lock steering to SteeringDir.
// Do not use "wait SteeringDuration", it gives strange results
// if RAILS time warping is used.
    wait until timestamp() > BurnStartTStmp.
    ChangeOrbitApsidesMFD["DisplayFlightStatus"]("Periapsis burn").
    lock throttle to 1.
    wait BurnDuration.
    ChangeOrbitApsidesMFD["DisplayFlightStatus"]("Finished").
    lock throttle to 0.
  }

local function SetMFD
  {
// Set the Multi-function Display.
// Notes:
//    -
// Todo:
//    -
    clearScreen.
    set terminal:width to 52.
    set terminal:height to 18.
    ChangeOrbitApsidesMFD["DisplayLabels"]
      (ship:name,ChangeName,ApsisAlt).
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
    when NextMFDRefreshSecs < timestamp():seconds
    then
      {
        ChangeOrbitApsidesMFD["DisplayRefresh"]
         (
          ship:apoapsis,
          ship:periapsis,
          BurnStartTStmp:seconds,
          timestamp():seconds
         ).
        set NextMFDRefreshSecs to NextMFDRefreshSecs+RefreshInterval.
        return MFDRefreshTriggerActive.
      }
  }

local function CheckForErrorsAndWarnings
  {
// Check for errors and warnings.
// Notes:
//    -
// Todo:
//    - 

    if not FatalError
      if ChangeName <> "CIRCULARIZATION"
        and ChangeName <> "CHANGEPE"
        and ChangeName <> "CHANGEAP"
        {
          ChangeOrbitApsidesMFD["DisplayError"]("Apsis change name is invalid").
          set FatalError to true.
        }
    if not FatalError
      if ship:status <> "ORBITING"
        and ship:status <> "SUB_ORBITAL"
        {
          ChangeOrbitApsidesMFD["DisplayError"]("Apsis cannot be adjusted due to ship status").
          set FatalError to true.
        }
    if not FatalError
      if WarpType <> "NOWARP"
        and WarpType <> "PHYSICS"
        and WarpType <> "RAILS"
        {
          ChangeOrbitApsidesMFD["DisplayError"]("WarpType parameter is invalid").
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

    set MFDRefreshTriggerActive to false.
// Ensure the triggers finish firing once more then stop.
    wait 0.

// Remove any global variables that might
// cause problems if they hang around.
//    unset MFDFunctions.

// Unlock the throttle and steering controls
// used by the Player.
    unlock throttle.
    unlock steering.

// One more physics tick before finishing this script,
// just to be on the safe side.
    wait 0.
  }