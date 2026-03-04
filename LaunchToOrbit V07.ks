// Program Title: LaunchToOrbit
// Author: JitteryJet
// Version: V07
// kOS Version: 1.5.1.0
// KSP Version: 1.12.5
// Description:
//  Launch a vessel into orbit.
//
//Notes:
//  Important Features:
//    - Turn types:
//        Zero-lift Gravity turn.
//        Linear-tangent Steering turn.
//    - The vessel can be launched from the surface of a body with or without an atmosphere.
//    - The vessel can be launched from where it was landed, not just the KSP launchpads.
//    - The orbit can be inclined.
//    - The orbit circularisation maneuver can be skipped.
//    - KSP Maneuver Nodes are not used.
//
//  The North and South Pole Krakens:
//    - If a launch is done very near the North or South Poles of a body the results may be unpredictable.
//      This is because the vessel's NORTH vector becomes undefined at the poles (think about it...).
//      The vessel's NORTH vector is used to calculate trajectories eg HEADING function etc.
//
//  Vessel Design:
//    - The vessel is assumed to have enough steering to allow the kOS Steering Manager to
//      steer the vessel.
//    - 
//
// Todo:
//    - Fix bug with reference to inclined orbits.
//    - Fix slight drift during ascent esp inclined orbits.
//    - Review thrust calculations for circularisation maneuver.
//    - Allow other types of gravity turns to be used.
//    - Test on airless bodies like The Mun.
//    -
//
// Update History:
//    07/03/2020 V01  - Created.
//    16/08/2020 V02  - Add maneuver steering time as a parameter.
//                    - Change orbit altitude from meters to kilometers.
//                    - Fixed staging issue where an engine "flame out" does
//                      not mean the stage has completely run out of fuel.
//                    - Declare local functions LOCAL to ensure they are
//                      not accidentally called from other scripts. The
//                      default scope for a function is GLOBAL.
//                    - Fixed handling for airless bodies.
//    03/12/2021 V03  - Test on Eve.
//                    - Allow launching straight up ie pitchover of zero.
//                    - Remove "cabin up" roll at launch.
//                    - Remove unnecessary "wait 0".
//                    - Remove unnecessary lock identifers from circularization code.
//                    - Upgraded to MiscFunctions V04.
//                    - Rewrote Multi Function Display (MFD).
//                    - Replaced the PID Loop controlled circularization burn with
//                      a timed circularization burn.
//                    - Test with KSP 1.12.2.
//    04/12/2021 V04  - Added a air speed limiter.
//    01/12/2023 V05  - Use MiscFunctions V05.
//                    - Added option to skip circularization.
//                    - Added removal of the staging trigger
//                      when the program finishes.
//    25/06/2024 V06  - Reduced steering backlash in the pitchover maneuver.
//                    - Remove orbital altitude and airspeed PID contoller.
//                    - Added Linear-tangent Steering (LTS) turn.
//                    - Changed zero-lift gravity turn to take into account
//                      the Drag Sensible Atmosphere limit.
//    02/01/2026 V07  - WIP
//                    - Add temporary Artemis 2 code.
//                    - Fix up time warp.
//                    - Improved the accuracy of the circularization maneuver.
//                    -
//
// Run parameters declarations.
//	OrbitAltkm         			Sea level altitude of the final orbit (km).
//  OrbitInclination        Inclination of the final orbit (deg).
//	LaunchDirection			    Launch direction "NORTH","SOUTH".
//  LaunchTurnType          Launch turn type "ZEROLIFT","LTS".                
//	TurnStartAltitude			  Ground level altitude of the start of turn (m).
//  TurnPitchoverAng        Pitchover angle to start the zero-lift turn (deg).
//  TurnPitchoverRate       Pitchover rate of turn (deg/s).
//  LTSTurnFinalAng         Final angle of the Linear-tangent Steering turn (deg)
//  LTSTurnDuration         Duration of the Linear Tangent Steering turn (s).
//  SteeringDuration        Duration of the steering required for the
//                          orbit circularisation maneuver (s).              
//  WarpType		  				  Type of timewarp "PHYSICS","RAILS" or "NOWARP".
//	LaunchCountdownPeriod		Period of time before launching (s).
//	SyncLaunch					    Synchronised launch. SYNC or NOSYNC.
//  Circ                    Circularization "CIRC","NOCIRC"

@lazyglobal off.

parameter OrbitAltkm to 100.
parameter OrbitInclination to 0.
parameter LaunchDirection to "NORTH".
parameter LaunchTurnType to "ZEROLIFT".
parameter TurnStartAltitude to 500.
parameter TurnPitchoverAngle to 10.
parameter TurnPitchoverRate to 1.0.
parameter LTSTurnFinalAng to 0.0.
parameter LTSTurnDuration to 300.0.
parameter SteeringDuration to 60.
parameter WarpType to "NOWARP".
parameter LaunchCountdownPeriod to 10.
parameter SyncLaunch to "NOSYNC".
parameter Circ to "CIRC".

// Load in library functions.
runoncepath("LaunchToOrbitMFD V03").
runoncepath("MiscFunctions V06").
runOncePath("OrbitBurnFunctions V03").

local OrbitAlt to OrbitAltkm*1000.
local LaunchCountdownCtr to LaunchCountdownPeriod.
local LaunchAltitude to ship:altitude.
local LaunchAzimuth to CalcLaunchAzimuth().
local CircDeltaV to 0.
local CircBurnStart to 0.
local CircEstBurnTime to 0.
local FatalError to false.
local MFDRefreshTriggerActive to true.
local MFDRefreshInterval to 0.1.
local StagingTriggerActive to true.
local BurnStartTimeSecs to 0.
local PitchStart to 0.
local SteeringDir to 0.
local ThrottleSet to 0.0.
local ManeuverPointUT to 0.

// Nominal pressure limit that defines the endoatmospheric/
// exoatmospheric boundary where I no longer care about
// atmospheric drag.   
local DragSensibleAtmosphereLimit
    to bodyAtmosphere("KERBIN"):altitudepressure(33000).

lock NavballPitch to 90-vang(ship:up:forevector,ship:facing:forevector).

// Other initialisations.
set ship:control:pilotmainthrottle to 0.
SAS off.
RCS off.
brakes off.
lights on.

// Main program.
clearscreen.
SetMFD().
CheckForErrorsAndWarnings().
CreateMFDRefreshTrigger().
if FatalError
  MFDFunctions["DisplayFlightStatus"]("Fatal Error").
else
  {
    LaunchCountdown().
    Launch().
    if LaunchTurnType = "ZEROLIFT"
      ZeroLiftTurn().
    else
    if LaunchTurnType = "LTS"
      LinearTangentSteeringTurn().
    else
      print 0/0.
    if Circ = "CIRC"
      { 
        CoastToCircularization().
        Circularize().
      }
    MFDFunctions["DisplayFlightStatus"]("Finished").
  }

//wait until false.
RCS off.
RemoveLocksAndTriggers().

local function LaunchCountdown
  {
// Count down to the launch.
// Notes:
//    -
// Todo:
//    -
		if SyncLaunch = "SYNC"
			SynchroniseLaunch().
    MFDFunctions["DisplayFlightStatus"]("Countdown").
    set BurnStartTimeSecs to time:seconds+LaunchCountdownPeriod.
    from {}
    until LaunchCountdownCtr = 0
    step {set LaunchCountdownCtr to LaunchCountdownCtr-1.}
    do
      {
        wait 1.
      }
  }

local function Launch
  {
// Launch the vessel.
// Notes:
//    - Launch straight up with no roll.
// Todo:
//    -
    lock throttle to ThrottleSet.
    set SteeringDir to lookdirup (ship:up:forevector,ship:facing:topvector).
    lock steering to SteeringDir.
    set ThrottleSet to 1.
		if ship:status = "PRELAUNCH"
    	stage.
    CreateStagingTrigger.
    legs off.
    MFDFunctions["DisplayFlightStatus"]("Launch").
    wait until (ship:altitude-LaunchAltitude >= TurnStartAltitude).
    MFDFunctions["DisplayFlightStatus"]("Roll").
// Artemis 2 roll.
    set SteeringDir to heading(90,90,LaunchAzimuth+90).
    wait 10. // Adjust roll time depending on how long it takes.
  }
        
local function ZeroLiftTurn
  {
// Do a Zero-lift Gravity Turn.
// Notes:
//    - The turn is started by a pitchover maneuver.
//    - The vessel follows the surface prograde while in
//      the drag sensible atmosphere and the orbital prograde
//      when above the drag sensible atmosphere or in a vacuum.
//    - 
// Todo:
//    - Check the turn works on on an airless body.
//    -
    local burnout to false.

// Artemis 2 code start. Comment out when not in use.
// The Service Module fairing is assumed to have this
// stage number.
    local FairingStageNumber to 6.
    local FairingJettisoned to false.
    local ClockStarted to false.
    local StartTime to 0.

// Artemis 2 code end.

    if TurnPitchoverAngle > 0
      Pitchover().
    MFDFunctions["DisplayFlightStatus"]("Zero-lift turn").
    until burnout
      {
        if ship:body:atm:altitudepressure(ship:altitude)
          > DragSensibleAtmosphereLimit
          set SteeringDir to lookDirUp(ship:velocity:surface,ship:facing:topvector).
        else
          {
// Artemis 2 code start. Comment out when not in use.
            if not FairingJettisoned
              {
                AG1 on.  // Jettison ECM fairing.
                wait 5.
                AG2 on.  // Jettison Launch Abort System.
                set FairingJettisoned to true.
              }
// Artemis 2 code end.
            set SteeringDir to lookDirUp(ship:velocity:orbit,ship:facing:topvector).
          }

// Artemis 2 code start. Comment out when not in use.
// Jettison the Service Module fairing and Launch Abort System
// around 1 minute after Solid Rocket Booster jettison.
//        if stage:number = FairingStageNumber
//          and not FairingJettisoned
//          {
//            if ClockStarted
//              {
//                if timestamp()>(StartTime+60)
//                  {
//                    AG1 on.  // Jettison fairing.
//                    wait 5.
//                    AG2 on.  // Jettison Launch Abort System.
//                    set FairingJettisoned to true.
//                    set ClockStarted to false.
//                  }
//              }
//            else
//              {
//                set StartTime to timestamp().
//                set ClockStarted to true.
//              }
//          }
// Artemis 2 code end.

        if ship:orbit:apoapsis > OrbitAlt
          set burnout to true.
        else
          wait 0.
      }
    set ThrottleSet to 0.
    set BurnStartTimeSecs to 0.
  }

local function LinearTangentSteeringTurn
  {
// Do a Linear-tangent Suidance turn.
// Notes:
//    - The endoatmospheric part of the turn is done
//      using a zero-lift gravity turn.
//    - This usage of Linear-tangent Steering assumes
//      a 'Flat Earth'. The burnout horizon is taken
//      from the position of the vessel where the LTS turn 
//      starts, not the current position of the vessel. 
//    - In this program burnout is when the desired orbit height is reached
//      or the LTS turn completes.
//    - The Linear-tangent pitch formula is based on the document titled:
//      "Derivation of Linear-Tangent Steering Laws by Frank M. Perkins 1966".
//    -
// Todo:
//    -
    local TanInitial to 0.0.
    local TanFinal to 0.0.
    local TimeFraction to 0.0.
    local BurnoutHorizonDir to heading(LaunchAzimuth,0).
    local PitchAng to 0.0.
    local StartTime to 0.0.
    local CurrentTime to 0.0.
    local burnout to false.

    if TurnPitchoverAngle > 0
      Pitchover().
    MFDFunctions["DisplayFlightStatus"]("Zero-lift turn").
    until ship:body:atm:altitudepressure(ship:altitude)
      < DragSensibleAtmosphereLimit
      {
        set SteeringDir to lookDirUp(ship:velocity:surface,ship:facing:topvector).
        wait 0.
      }
//    kuniverse:pause().
    MFDFunctions["DisplayFlightStatus"]("Linear-tan turn").
    set StartTime to timestamp():seconds.
    set CurrentTime to StartTime.
    set TanInitial to tan(NavballPitch).
    set TanFinal to tan(LTSTurnFinalAng).
// Do the LTS turn for the specified turn duration
// or the orbit altitude is reached.
    until TimeFraction >= 1
      or burnout
      {
        set PitchAng to
          arctan(TanInitial-(TanInitial-TanFinal)*TimeFraction).
        set SteeringDir to
          lookdirup((angleaxis(-PitchAng,BurnoutHorizonDir:starvector)*BurnoutHorizonDir):forevector,ship:facing:topvector).
        set CurrentTime to timestamp():seconds.
        set TimeFraction to (CurrentTime-StartTime)/LTSTurnDuration.
        MFDFunctions["DisplayDiagnostic"]
          (round(PitchAng,3),round(TimeFraction,3)).
        if ship:orbit:apoapsis > OrbitAlt
          set burnout to true.
        wait 0.
      }
// If the altitude was not reached keep going without
// any more turning.
    until burnout
      {
        if ship:orbit:apoapsis > OrbitAlt
          set burnout to true.
        wait 0.
      }
    set ThrottleSet to 0.
    set BurnStartTimeSecs to 0.
  }

local function Pitchover
  {
// Do a pitchover maneuver to start a gravity turn.
// Notes:
//    - The gravity turn is "zero-lift" (or near zero-lift) if
//      in an atmosphere.
//    - 
// Todo:
//    - Think about whether the thrust vector should also
//      align with the velocity vector on an airless body.
//    -
    local PitchoverAng to 0.0.

    MFDFunctions["DisplayFlightStatus"]("Pitchover").
    set PitchStart to timestamp().
    set PitchoverAng to 0.

// Control the rate of turn.
    until PitchoverAng > TurnPitchoverAngle
      {
        set SteeringDir to
//          lookdirup(heading(LaunchAzimuth,90-PitchoverAng):forevector,ship:facing:topvector).
// Artemis 2 roll.
          lookdirup(heading(LaunchAzimuth,90-PitchoverAng):forevector,-ship:up:forevector).
        set PitchoverAng to TurnPitchoverRate*(timestamp()-PitchStart):seconds.
      }

// Align the thrust vector with the velocity vector if in
// an atmosphere. This is consistent with the definition of
// a "zero-lift gravity turn".
    if ship:body:atm:exists
      {
// Wait for the initial pitchover to settle.
        wait until vang(ship:facing:forevector,steeringManager:target:forevector) < 1.
// Wait for the surface velocity vector to align with the vessel.
        MFDFunctions["DisplayFlightStatus"]("AOA Settle").
        wait until vang(ship:facing:forevector,ship:velocity:surface) < 1.
      }
  }

local function CoastToCircularization
  {
// Coast to the beginning of the circularization maneuver.
// Notes:
//    -
// Todo:
//		-
    local CircEstHalfDvTime to 0.0.
    set ManeuverPointUT to timestamp()+eta:apoapsis.
    set CircDeltaV to CircularizationDeltaV().
    set CircEstBurnTime to DeltaVBurnTimeIdeal(CircDeltaV).
    MFDFunctions["DisplayManeuver"]
      (
        CircEstBurnTime,
        CircDeltaV
      ).
    set CircEstHalfDvTime to DeltaVBurnTimeIdeal(CircDeltaV/2).
    set CircBurnStart to ManeuverPointUT:seconds-CircEstHalfDvTime.
    set BurnStartTimeSecs to CircBurnStart.
    MFDFunctions["DisplayFlightStatus"]("Coast to circ").

// Wait until the start of the circularization maneuver.
    DoSafeWait (timestamp(CircBurnStart-SteeringDuration),WarpType).
  }

local function Circularize
  {
// Circularize the orbit.
// Notes:
//		-
// Todo:
//    -
    local BurnVec to v(0,0,0).
// Orient the ship for the circularization burn.
    set BurnVec to velocityat(ship,ManeuverpointUT):orbit.
    set SteeringDir to lookdirup(BurnVec,ship:facing:topvector).
    MFDFunctions["DisplayFlightStatus"]("Steering").
    wait SteeringDuration.

// Circularization burn.
    MFDFunctions["DisplayFlightStatus"]("Circularizatn").
    set ThrottleSet to 1.
    wait CircEstBurnTime.
    set ThrottleSet to 0.
    MFDFunctions["DisplayFlightStatus"]("Circ finished").
	}

local function CalcLaunchAzimuth
  {
// Return the Launch Azimuth which is the angle from north required to
// launch into a specified inclined orbit from a launch site.
// Allow for the rotation of the SOI body at the launch site.
// Notes:
//  01. Calculation variables:
//      Orbit Inclination. (0-180).
//        Desired orbital inclination.
//      Launch Type. Values ("NORTH","SOUTH").
//        Launch to the north or launch to the south. This shows which of
//        the two solutions for a given orbital inclination is required.
//      Inertial azimuth. Values (-90 to 90).
//        First approximation. Does not include compensation for body rotation.
//      Rotational azimuth. Values (-90 to 90).
//        Inertial azimuth plus compensation for body rotation.
//      Launch azimuth. Values (0-360).
//        The compass heading to launch to.
//      Equatorial velocity.
//        Rotational velocity of the body's equator at sea level.
//      Orbital velocity.
//        Orbital velocity at the target orbit.
//  02. The plane of the orbit cannot be closer to the equator than the
//      latitude of the launch site. In this case set the inclination to
//      the same as the launch site ie launch due east or due west depending
//      on prograde or retrograde.
//  03. The formula to calculate inertial azimuth usually produces two
//      solutions that results in the same orbital inclination. These solutions
//      are "North" launches and "South" launches - which one is wanted has to
//      be specified.
    local cosLat to cos(ship:latitude).
    local cosOrbitInc to cos(OrbitInclination).
    local InAz to 0.
    local RotAz to 0.
    local ObtV to 0.
    local EqV to 0.
    local LaunchAz to 0.

    if abs(cosOrbitInc) <= abs(cosLat)
      set InAz to arcsin(cosOrbitInc/cosLat).
    else
      if OrbitInclination <= 90
        set InAz to 90.  // Launch due east.
      else
        set InAz to -90. // Launch due west.

    set ObtV to sqrt (ship:body:mu/(ship:body:radius+OrbitAlt)).
    set EqV to 2*constant:pi*ship:body:radius/ship:body:rotationperiod.
    set RotAz to arctan((ObtV*sin(InAz)-EqV*cosLat)/(ObtV*cos(InAz))).

    //set RotAz to InAz.

// Convert the azimuth calculated to a compass heading azimuth.
    if LaunchDirection = "NORTH"
      if RotAz >= 0
        set LaunchAz to RotAz.
      else
        set LaunchAz to 360 + RotAz.
    else
    if LaunchDirection = "SOUTH"
      set LaunchAz to 180 - RotAz.

    return LaunchAz.
  }

local function CreateStagingTrigger
  {
// Create trigger to stage automatically when the stage can no longer
// produce thrust.
// Notes:
//		-
// Todo:
//		- Test with sepratrons - they count as solid fuel?
//    -
    when
      ship:maxthrust = 0
      or (stage:liquidfuel = 0 and stage:solidfuel = 0)
    then
      {
        stage.
        until stage:ready {wait 0.}
        if stage:number > 0
          return StagingTriggerActive.
      }
  }

local function CircularizationDeltaV
  {
// Calculate the change in velocity required to raise the periapsis to the same
// altitude as the apoapsis.
// Refer to the "Vis-viva" equation.
    local dVold to sqrt(ship:body:mu * (2/(ship:body:radius+ship:obt:apoapsis) -
      1/ship:obt:semimajoraxis)).
    local dVnew to sqrt(ship:body:mu * (1/(ship:body:radius+ship:obt:apoapsis))).
    return (dVnew - dVold).
  }

local function DeltaVBurnTimeIdeal
  {
// Estimate the burn time for the specified deltaV based on the vessel
// characteristics. 
// Notes:
//    - The equation allows for changes in mass as fuel is burnt.
//      Refer to the "Ideal Rocket Equation".
//    - The estimate assumes that thrust and ISP remain constant. These
//      assumptions do not allow for any staging etc that can occur during a
//      burn.
    parameter dV.

    local minitial is 0.
    local mfinal is 0.
    local ISP is 0.
    local g0 is 9.82.
    local mpropellent is 0.
    local mdot is 0.
    local thrust is 0.
    local BurnTime is 0.

    set minitial to ship:mass.
    set thrust to ship:availablethrust.
    set ISP to CurrentISP().

    set mfinal to minitial*constant:e^(-dV/(ISP*g0)).
    set mpropellent to minitial-mfinal.
    set mdot to thrust/(ISP*g0).
    set BurnTime to mpropellent/mdot.

    return BurnTime.
  }

local function CurrentISP
  {
// Calculate the current ISP of the vessel.
// Notes:
//    -
// Todo:
//    - Does not allow for different engine types on the stage - the contribution
//      to the ISP is probably dependent on the thrust of the engine as well.
//    - Check this code with multiple engines, it does not look right!
//    - 
//    
    local ISP is 0.
    local englist is 0.
    list engines in englist.
    for eng in englist
      {
        if eng:stage = stage:number
          set ISP to ISP + eng:isp.
      }
    return ISP.
  }

local function SynchroniseLaunch
  {
// Synchronise the launch to the start of the next "period".
// Notes:
//		- The purpose of a synchronised launch is to allow more than one vessel
//			to be launched at the same time for races, synchronised flying etc.
//		- Is it possible a whole second could be missed? Unlikely??
// ToDo:
//		- This sychronisation method is a bit rough. It can be improved.
		local period to 180.

    MFDFunctions["DisplayFlightStatus"]("Sync launch").
		set Launchcountdownctr to
			LaunchCountdownCtr +
			period-mod(floor(time:seconds),period)-1.

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
    set terminal:height to 26.
    MFDFunctions["DisplayLabels"]
      (
        ship:name,
        TurnStartAltitude,
        TurnPitchoverAngle,
        OrbitAlt,
        OrbitInclination,
        LaunchDirection,
        LaunchAzimuth,
        LTSTurnDuration,
        LTSTurnFinalAng
      ).
  }

local function CreateMFDRefreshTrigger
  {
// Create a trigger to refresh the the Multi-function Display periodically.
// Notes:
//    -
// Todo:
//		-
    local NextMFDRefreshTime to time:seconds.
    local StageNum to 0.
    when NextMFDRefreshTime < time:seconds
    then
      {
        if ship:status = "PRELAUNCH"
          set StageNum to stage:number-1.
        else
          set StageNum to stage:number.
        MFDFunctions["DisplayRefresh"]
         (
          StageNum, 
          NavballPitch,
          ship:apoapsis,
          ship:periapsis,
          ship:orbit:eccentricity,
          BurnStartTimeSecs,
          timestamp():seconds
         ).
        set NextMFDRefreshTime to NextMFDRefreshTime+MFDRefreshInterval.
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
    if ship:status <> "PRELAUNCH"
      and ship:status <> "LANDED"
      {
        MFDFunctions["DisplayError"]("Vessel is in flight or has splashed down").
        set FatalError to true.
      }
    if not FatalError
      if Circ <> "CIRC"
        and Circ <> "NOCIRC"
        {
          MFDFunctions["DisplayError"]("Circ parameter is invalid").
          set FatalError to true.
        }
    if not FatalError
      if LaunchTurnType <> "ZEROLIFT"
        and LaunchTurnType <> "LTS"
        {
          MFDFunctions["DisplayError"]("LaunchTurnType parameter is invalid").
          set FatalError to true.
        }
    if not FatalError
      if WarpType <> "NOWARP"
        and WarpType <> "PHYSICS"
        and WarpType <> "RAILS"
        {
          MFDFunctions["DisplayError"]("WarpType parameter is invalid").
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
    set MFDRefreshTriggerActive to false.
    set StagingTriggerActive to false.

// Wait long enough so the triggers have finished
// firing before deallocating anything the triggers
// use.
    wait MFDRefreshInterval.

// Remove any global variables that might
// cause problems if they hang around
// for too long.
    unset MFDFunctions.

    unlock throttle.
    unlock steering.
    wait 0.
  }