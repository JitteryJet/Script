// Name: StarshipAutopilot
// Author: JitteryJet
// Version: V06
// kOS Version: 1.3.2.0
// KSP Version: 1.11.2
// Description:
//    Autopilot for the SpaceX Starship.
//
// Assumptions:
//    - High Altitude Test mode:
//      - The Starship spacecraft is running this autopilot program.
//      - The vessel is the Spaceship spacecraft stage and is on the KSC launchpad or has landed.
//    - Return To Launch Site mode:
//      - The Super Heavy stage is running this autopilot program.
//      - The vessel is the Super Heavy stage attached to the Starship spacecraft stage
//        either on the KSC launchpad or landed, or the vessel is the Super Heavy stage
//        only and is flying or sub orbital.
//
// Notes:
//    - "Starship" refers to both the SpaceX Starship system and the
//      upper stage/spacecraft of the system.
//    - Assumes the vessel will modeled after the SpaceX Starship SN10 spacecraft.
//    - This script was designed and tested with a vessel that had these attributes:
//      - A single engine instead of a 3-engine cluster. There are no single engine shutdowns
//        to control thrust like the SpaceX Starship SN10 used.
//      - Lots of thrust vectoring.
//      - Reaction wheels and RCS to control attitude instead of flaps
//        and cold-gas thrusters.
//    - The pinpoint landing control will handle around 250 metres of error reliably.
//      Ie the vessel has to be dropped within around 250 metres of the landing spot to have
//      a good chance of landing on the landing spot.
//
// Todo:
//    - Add the Super Heavy booster stage.
//
// Update History:
//    21/04/2021 V01  - Created for the Starship SN10 High-Altitude Flight Test
//                      simulation.
//    24/04/2021 V02  - Improved the compensation for horizontal drift when
//                      some of the engines are shut down.
//                    - Added engine shut downs to the hoverslam.
//                    - Added land on one engine.
//    30/04/2021 V03  - Changed flight sequence to be more KSP-like
//                      eg removed engine shut downs etc.
//                    - Added a launch countdown period.
//                    - Added synchronised launches.
//                    - Removed the code that assumed a 3-engine cluster.
//                    - Added stopping distance calculations to the suicide burn.
//                    - Added glide path guidance.
//                    - Added a estimated landing spot indicator to the screen.
//    03/05/2021 V04  - Fixed up bug in predicted landing spot calculations.
//                    - Fixed pinpoint landings.
//                    - Added landing spot as a parameter.
//    21/05/2021 V05  - Added Super Heavy return to launch site demo.
//    01/06/2021 V06  - Added flap-based attitude control.
//                    - 
@lazyglobal off.
// Parameter descriptions.
//    AutopilotMode               "HIGHALTTEST" or "RETURNTOLAUNCHSITE".
//    LandingGeo                  Geoposition of the landing spot.                           
//	  WarpType                    "PHYSICS","RAILS" or "NOWARP".
//	  LaunchCountdownDuration     Period of time before launching (s).
//	  LaunchSyncPeriod            Sync launch to this period (s). Zero is no sync.
parameter AutopilotMode to "HIGHALTITUDETEST".
parameter LandingGeo to latlng(-0.097199999999999995,285.44229999999999).  // KSC Launchpad.
parameter WarpType to "NOWARP".
parameter LaunchCountdownDuration to 5.
parameter LaunchSyncPeriod to 0.

// Load in library functions.
runoncepath("MiscFunctions V04").
runoncepath("StarshipAutopilotMFD V02").

// Vertical Speed PID controller to
// regulate the vertical ascent and descent speed of
// the Starship spacecraft via the throttle setting.
// Process Variable:
//    Vertical speed.
// Control Variable:
//    Throttle.
local VerticalSpeedPID to pidLoop().
set VerticalSpeedPID:KP to 0.1.
set VerticalSpeedPID:KI to 0.1.
set VerticalSpeedPID:KD to 0.
set VerticalSpeedPID:minoutput to 0.
set VerticalSpeedPID:maxoutput to 1.
set VerticalSpeedPID:epsilon to 0.
set VerticalSpeedPID:setpoint to 0.

// Glide path PID controller to
// regulate the glide towards the position
// over the landing spot.
// Process Variable:
//    Horizontal speed towards or
//    away from the landing spot.
// Control Variable:
//    Pitch down angle.
local GlidePathPID to pidLoop().
set GlidePathPID:KP to 5.
set GlidePathPID:KI to 0.1.
set GlidePathPID:KD to 0.
set GlidePathPID:minoutput to -10.
set GlidePathPID:maxoutput to 10.
set GlidePathPID:epsilon to 0.
set GlidePathPID:setpoint to 5.

// Pitch PID controller.
// Process Variable:
//    Vessel pitch angle.
// Control Variable:
//    Flap angle.
local PitchPID to pidLoop().
set PitchPID:KP to 5.
set PitchPID:KI to 1.
set PitchPID:KD to 0.
set PitchPID:minoutput to -90.
set PitchPID:maxoutput to 90.
set PitchPID:epsilon to 0.
set PitchPID:setpoint to 0.

// Yaw PID controller.
// Process Variable:
//    Vessel yaw angle.
// Control Variable:
//    Flap angle.
local YawPID to pidLoop().
set YawPID:KP to 1.
set YawPID:KI to 0.01.
set YawPID:KD to 0.
set YawPID:minoutput to -1.
set YawPID:maxoutput to 1.
set YawPID:epsilon to 0.
set YawPID:setpoint to 0.

// Roll PID controller.
// Process Variable:
//    Vessel roll angle.
// Control Variable:
//    Flap angle.
local RollPID to pidLoop().
set RollPID:KP to 1.
set RollPID:KI to 0.01.
set RollPID:KD to 0.
set RollPID:minoutput to -1.
set RollPID:maxoutput to 1.
set RollPID:epsilon to 0.
set RollPID:setpoint to 0.

// Vessel UP with no roll around the forward axis.
local lock NoRollUPDir to lookdirup(ship:up:forevector,ship:facing:topvector).

// Use the navball convention.
local lock VessPitchAng to 90-vang(ship:up:forevector,ship:facing:forevector).
local lock VessRollAng to 90-vang(ship:up:forevector,ship:facing:starvector).

// The predicted landing spot is where the surface velocity vector
// intersects the plane the landing spot sits on. This is only
// approximate.
local lock PredictedLandingSpot to
      CalcLinePlaneIntersection
        (
          ship:velocity:surface,
          ship:up:forevector,
          ship:position,
          LandingGeo:position
        ).

// Vecdraws I want to preserve until the program terminates.
local NorthVD to vecdraw().

// Resolve the part references to the flaps.
// This code will need to be reviewed and fixed for each new craft as
// the part references assigned in Vehicle Assembly are
// unpredictable.
// Flap Angle conventions used in this script:
//   0 degrees: Fully retracted.
//   90 degrees: Fully extended 
local FlapPartList is ship:partsnamed("hinge.04").
local ForwardPortFlap is FlapPartList[0].
local ForwardStarFlap is FlapPartList[1].
local AftPortFlap is FlapPartList[2].
local AftStarFlap is FlapPartList[3].
// Set flap parameters to values expected by
// this script so they do not have to be set
// in Vehicle Assembly.
for p in FlapPartList
  {
	  local m is p:getmodule("ModuleRoboticServoHinge").
//		m:setfield("Angle Limit",180).
		m:setfield("Traverse Rate",180).
    m:setfield("Damping",0).
	}
// Flap neutral angle.
// This is the angle of the flaps
// with no pitch,yaw,roll adjustments.
// This value has to be large enough to
// allow for the sum of all the angle adjustments to
// stay in the range 0-90.
local FlapNeutralAng to 90.
// Flap angles.
local ForwardPortFlapAng to 0.
local ForwardStarFlapAng to 0.
local AftPortFlapAng to 0.
local AftStarFlapAng to 0.
// Piston landing gear.
local GearPartList is ship:partsnamed("piston.04").
for p in GearPartList
  {
	  local m is p:getmodule("ModuleRoboticServoPiston").
//		m:setfield("Angle Limit",180).
		m:setfield("Traverse Rate",1).
    m:setfield("Damping",0).
	}

local BurnStartTimeUT to time(0).
local FatalError to false.
local MFDRefreshTriggerActive to true.
local LandingSpotIndicatorRefreshTriggerActive to false.
local LaunchCountdownCtr to 0.
local StoppingDistance to 0.
local MFDWidth to 50.
local MFDHeight to 25.

// Other initialisations.
set ship:control:pilotmainthrottle to 0.
SAS off.
RCS off.
brakes off.
lights on.
  
// Main program.
SetMFD().
CheckForErrorsAndWarnings().
if not FatalError
  {
    CreateMFDRefreshTrigger().
    if AutopilotMode = "HIGHALTITUDETEST"
      HighAltitudeTest().
    else
    if AutopilotMode = "RETURNTOLAUNCHSITE"
      ReturnToLaunchSite().
  }
//wait until false.
RCS off.
RemoveLocksAndTriggers().

local function HighAltitudeTest
  {
// High Altitude Test autopilot mode.
// Notes:
//    -
// Todo:
//    -
    TestFlaps().
//    wait until false.
    AscendToHorizontalFlipHeight().
    HorizontalFlipAndDescend().
    VerticalFlipAndLand().
  }

local function ReturnToLaunchSite
  {
// Return to Launch Site autopilot mode.
// Notes:
//    - Assumption: This vessel is the active vessel.
// Todo:
//    -
    lock throttle to 0.
    StarshipAutopilotMFD["DisplayFlightStatus"]("Staging wait").
    wait until ship:altitude > 45000.
    set kuniverse:activevessel to ship.
    kuniverse:pause.
    until stage:ready {wait 0.}
    stage.
    wait 0.
    Boostback().
    BoostbackLanding().
  }

local function Boostback
  {
// Do the Boostback maneuver.
// Notes:
//    - The boostback maneuver reverses the current trajectory
//      and sets up a trajectory back to the landing site.
//    - It is likely the vessel will continue to climb
//      for a period of time after the boostback.
// Todo:
//    -
    StarshipAutopilotMFD["DisplayFlightStatus"]("Boostback").
    rcs on.
    lock steering to -vxcl(ship:up:forevector,ship:velocity:surface).
    brakes on.
    SetAirbrakeControlSurfaces(true).
    wait until vang(ship:facing:forevector,steeringManager:target:forevector) < 1.
    lock throttle to 1.
    wait until ship:groundspeed < 10.
    lock steering to SteeringManager:target.
    wait 3.
    lock throttle to 0.
    lock steering to ship:up.
    wait until ship:verticalspeed < -10.
    rcs off.
  }

local function BoostbackLanding
  {
// Do the the maneuver to land the vessel at the landing site.
// Notes:
//    - This does not include an "entry burn" to reduce the supersonic
//      speed as it is not required in a KSP simulation.
//    - The Stopping Distance does not take into account air resistance.
// Todo:
//    - Think how to allow for air resistance - it makes a
//      big difference to the stopping distance (~5km).
//    -
    local StoppingDistanceFudgeFactor to 5900.
    StarshipAutopilotMFD["DisplayFlightStatus"]("Landing").
    lock steering to -ship:velocity:surface.
    local finished to false.
    until finished
      {
        set StoppingDistance to
          CalcStoppingDistance.
        if alt:radar < (StoppingDistance-StoppingDistanceFudgeFactor)
          set finished to true.
        wait 0.
      }
    CreateLandingSpotIndicator().
    VerticalSpeedPID:reset.
    set VerticalSpeedPID:setpoint to -5.
    lock throttle to VerticalSpeedPID:update(time:seconds,ship:verticalspeed).
    wait until ship:verticalspeed >= VerticalSpeedPID:setpoint.
    lock steering to ship:up.
    wait until ship:status = "LANDED".
// Keep the vessel upright to reduce the chances of it toppling over.
    lock steering to NoRollUPDir.
    lock throttle to 0.
    StarshipAutopilotMFD["DisplayFlightStatus"]("Landed").
    wait 5.
    set LandingSpotIndicatorRefreshTriggerActive to false.
    set NorthVD:show to false.
  }

local function AscendToHorizontalFlipHeight
  {
// Ascend to the height at which to start the horizontal flip.
// Finish the ascent with a hover. 
// Notes:
//    - This is for setting up a "High Altitude Test".
//    -
//      
// Todo:
//    -
    local LaunchpadClearanceSecs to 1.
    local MaxAscentHeight to 8000.
    local MaxAscentSpeed to 200.
    set VerticalSpeedPID:setpoint to MaxAscentSpeed.
    ExtendForwardFlaps().
    ExtendAftFlaps().
    Launch().
    StarshipAutopilotMFD["DisplayFlightStatus"]("Launch").
// Short wait to enable the vessel to clear the launch pad
// and gain some surface velocity along the forward axis.
    wait LaunchpadClearanceSecs.
    RaiseLandingGear().
    StarshipAutopilotMFD["DisplayFlightStatus"]("Ascent").
//    lock steering to lookdirup(OffsetUPVec,ship:facing:topvector).
    wait until ship:altitude > MaxAscentHeight.
    StarshipAutopilotMFD["DisplayFlightStatus"]("Hover").
    set VerticalSpeedPID:setpoint to 0.
    wait until ship:verticalspeed <= 0.
    kuniverse:pause().
  }

local function HorizontalFlipAndDescend
  {
// Do a horizontal flip maneuver and descend towards
// the landing spot.
// Notes:
//    - Assumption: The horizontal flip is done from a
//      powered hover ie the flip maneuver is done using
//      thrust vectoring.
//    - The stopping distance error margin has to be guessed or
//      derived from trial-and-error.
//    - Don't forget to balance the COM during Vehicle Assembly otherwise
//      it could be difficult to maintain the horizontal attitude.
// Todo:
//    - Think about what should happen if the vessel overshoots the
//      landing spot.
//    - Think about how the stopping distance error margin could be calculated.
//    -
    local StoppingDistanceErrorMargin to 400.
    local finished to false.
    local PitchCV to 0.
    local YawCV to 0.
    local RollCV to 0.
    local PitchAngVel to 0.
    local YawAngVel to 0.
    local RollAngVel to 0.
    local PitchAng to 0.
    local YawAng to 0.
    local RollAng to 0.
    local TimeSecs to 0.
    local PreviousTimeSecs to 0.
    local PreviousPitchAng to 0.
    local PreviousYawAng to 0.
    local PreviousRollAng to 0.
    local DeltaTimeSecs to 0.
    local lock HVelVec to vdot(ship:velocity:surface,LandingGeo:altitudeposition(ship:altitude):normalized).
    local lock PitchRot to
      angleaxis
        (
          GlidePathPID:update
            (time:seconds,
             HVelVec),
            ship:facing:starvector
        ).
// Horizontal flip.
    StarshipAutopilotMFD["DisplayFlightStatus"]("Horizontal flip").
// Roll the vessel so the flip can be done by rotating in one plane.
    lock steering to
      lookdirup(ship:up:forevector,-ship:north:forevector).
    wait 5.
// Flip to horizontal.
    RetractAftFlaps().
    lock throttle to 0.
    rcs on.
// Switch off the yaw control during the flip so
// the vessel rotates straight down.
    set steeringManager:yawpid:kp to 0.
    set steeringManager:yawpid:ki to 0.
    set steeringManager:yawpid:kd to 0.
    lock steering to 
      lookdirup(ship:north:forevector,ship:up:forevector).
//    wait until NearEqual(VessPitchAng,0,1).
    wait 10.
    rcs off.
    lock throttle to 0.
    unlock steering.
    steeringmanager:resettodefault().
// Steer towards the landing spot using the flaps while keeping
// the vessel flat relative to the ground to reduce the descent speed.
    set LandingSpotIndicatorRefreshTriggerActive to true.
    CreateLandingSpotIndicator().
    set PreviousTimeSecs to time:seconds-1. // dummy value.
    set PreviousPitchAng to VessPitchAng.
    set PreviousYawAng to ship:bearing.
    set PreviousRollAng to VessRollAng.
    until finished
      {
        set TimeSecs to time:seconds.
        set DeltaTimeSecs to TimeSecs-PreviousTimeSecs.
        set PitchAng to VessPitchAng.
        set YawAng to ship:bearing.
        set RollAng to VessRollAng.
// Calculate the current angular velocities.
        set PitchAngVel to (PitchAng-PreviousPitchAng)/DeltaTimeSecs.
        set YawAngVel to (YawAng-PreviousYawAng)/DeltaTimeSecs.
        set RollAngVel to (RollAng-PreviousRollAng)/DeltaTimeSecs.
        set PreviousTimeSecs to TimeSecs.
        set PreviousPitchAng to PitchAng.
        set PreviousYawAng to YawAng.
        set PreviousRollAng to RollAng.
// 
        set PitchPID:setpoint to -PitchAng.
        set YawPID:setpoint to -YawAng.
        set RollPID:setpoint to RollAng.
// Calculate the Control Variable. This is basically a flap angle adjustment.
        set PitchCV to PitchPID:update(TimeSecs,PitchAngVel).
        set YawCV to YawPID:update(TimeSecs,YawAngVel).
        set RollCV to RollPID:update(TimeSecs,RollAngVel).
// Apply flap pitch adjustment.
// Rotate the forward flaps opposite to the aft flaps.
        if PitchCV < 0 
          {
            set ForwardPortFlapAng to FlapNeutralAng+PitchCV.
            set ForwardStarFlapAng to FlapNeutralAng+PitchCV.
            set AftPortFlapAng to FlapNeutralAng.
            set AftStarFlapAng to FlapNeutralAng.
          }
        else
          {
            set ForwardPortFlapAng to FlapNeutralAng.
            set ForwardStarFlapAng to FlapNeutralAng.
            set AftPortFlapAng to FlapNeutralAng-PitchCV.
            set AftStarFlapAng to FlapNeutralAng-PitchCV.
          }
// Apply flap yaw adjustment.
// Yaw control comes from rotating the diagonally opposite
// flaps in the same direction, while rotating the opposite
// flaps in the opposite direction. 
        if YawCV < 0
          {
            set ForwardPortFlapAng to ForwardPortFlapAng+YawCV. 
            set AftStarFlapAng to AftStarFlapAng+YawCV.
          }
        else
          {
            set ForwardStarFlapAng to ForwardStarFlapAng-YawCV.
            set AftPortFlapAng to AftPortFlapAng-YawCV.
          }
        
// Apply flap roll adjustment.
// Roll control comes from rotating the flaps along one side
// in the opposite direction to the flaps along the other side. 
        if RollCV > 0
          {
            set ForwardStarFlapAng to ForwardStarFlapAng-abs(RollCV).
            set AftStarFlapAng to AftStarFlapAng-abs(RollCV).
          }
        else
          {
            set ForwardPortFlapAng to ForwardPortFlapAng-abs(RollCV).
            set AftPortFlapAng to AftPortFlapAng-abs(RollCV).
          }
// Ensure the sum of the flap adjustments is in range 0-90.
// This may not be strictly necessary, but better to be safe than sorry.
        set ForwardPortFlapAng to clamp(ForwardPortFlapAng,0,90).
        set ForwardStarFlapAng to clamp(ForwardStarFlapAng,0,90).
        set AftPortFlapAng to clamp(AftPortFlapAng,0,90).
        set AftStarFlapAng to clamp(AftStarFlapAng,0,90).        
        SetFlapAngle(ForwardPortFlap,ForwardPortFlapAng).
        SetFlapAngle(ForwardStarFlap,ForwardStarFlapAng).
        SetFlapAngle(AftPortFlap,AftPortFlapAng).
        SetFlapAngle(AftStarFlap,AftStarFlapAng).
        DisplayFlapDiagnostics().      
        set StoppingDistance to
          CalcStoppingDistance
          +StoppingDistanceErrorMargin.
        if ship:altitude-LandingGeo:terrainheight < StoppingDistance
          set finished to true.
        wait 0.
      }
  }

local function RetractForwardFlaps
  {
// Retract the forward flaps.
// Notes:
//    -
// Todo:
//    -
    SetFlapAngle(ForwardPortFlap,0).
    SetFlapAngle(ForwardStarFlap,0).
  }

local function RetractAftFlaps
  {
// Retract the aft flaps.
// Notes:
//    -
// Todo:
//    -
    SetFlapAngle(AftPortFlap,0).
    SetFlapAngle(AftStarFlap,0).
  }

local function ExtendForwardFlaps
  {
// Extend the forward flaps.
// Notes:
//    -
// Todo:
//    -
    SetFlapAngle(ForwardPortFlap,90).
    SetFlapAngle(ForwardStarFlap,90).
  }

local function ExtendAftFlaps
  {
// Extend the forward flaps.
// Notes:
//    -
// Todo:
//    -
    SetFlapAngle(AftPortFlap,90).
    SetFlapAngle(AftStarFlap,90).
  }

local function VerticalFlipAndLand
  {
// Do a vertical flip maneuver and land.
// Notes:
//    - Try and start the flip before the landing spot is reached -
//      overshoots do not work well with this code.
//    - This code contains some "magic numbers" which might have
//      to be tuned depending on the performance characteristics
//      of the vessel.
//    - The yaw control is switched off during the horizontal flip
//      as yaw is not required while flipping (the Steering Manager
//      does not know that). Because the engines are switched on when
//      the flip is still in progress, any yaw pushes the vessel off course.
//    - 
// Todo:
//    -

// This steering vector is a hack until I can design a better drift control
// system. It works OK most of the time.
    lock NudgeVelocityVec to
      LandingGeo:altitudeposition(LandingGeo:terrainheight):normalized*0.05.
// Switch off the yaw control during the vertical flip.
    set steeringManager:yawpid:kp to 0.
    set steeringManager:yawpid:ki to 0.
    set steeringManager:yawpid:kd to 0.
    RetractAftFlaps().
    lock steering to lookdirup(-ship:velocity:surface,-ship:north:forevector).
    VerticalSpeedPID:reset().
    set VerticalSpeedPID:minoutput to 0.
    set VerticalSpeedPID:setpoint to -20.
    lock throttle to VerticalSpeedPID:update(time:seconds,ship:verticalspeed).
    until ship:verticalspeed >= VerticalSpeedPID:setpoint
      wait 0.
    RetractForwardFlaps().
    LowerLandingGear().
// Restore the yaw control.
    steeringmanager:resettodefault().
// Hover for several seconds to help kill off horizontal speed.
    wait 10.
// Descend to the landing spot.
    lock steering to lookdirup(ship:up:forevector,-ship:north:forevector).
    set VerticalSpeedPID:setpoint to -2.
    until ship:verticalspeed >= VerticalSpeedPID:setpoint
      wait 0.
    until ship:status = "LANDED"
      wait 0.
// Keep the vessel upright to reduce the chances of it toppling over.
    lock steering to NoRollUPDir.
    lock throttle to 0.
    StarshipAutopilotMFD["DisplayFlightStatus"]("Landed").
    wait 5.
    set LandingSpotIndicatorRefreshTriggerActive to false.
    set NorthVD:show to false.
  }

local function Launch
  {
// Launch the vessel.
// Notes:
//    - The vessel will launch straight up with no roll.
//    - The purpose of a synchronised launch is to allow more than one vessel
//			to be launched at the same time for races, synchronised flying etc.
//    - Be aware there are restrictions when flying multiple vessels
//      when they are not the active vessel even if they are within load distance
//      eg staging only works on the active vessel.
//    -
// Todo:
//    -
    set LaunchCountdownCtr to LaunchCountdownDuration.
    if LaunchSyncPeriod = 0
      {
        if LaunchCountdownDuration > 0
          {
            set LaunchCountdownCtr to LaunchCountdownDuration.
            LaunchCountdown().
          }
      }
    else
      {
			  set LaunchCountdownCtr to
          LaunchCountdownCtr+SecondsUntilNextSyncPeriod(LaunchSyncPeriod).
        LaunchCountdown().
      }
		if ship:status = "PRELAUNCH"
    	stage.
    lock steering to NoRollUPDir.
    lock throttle to VerticalSpeedPID:update(time:seconds,ship:verticalspeed).
  }

local function LaunchCountdown
  {
// Launch countdown.
// Notes:
//    -
// Todo:
//    -
    set BurnStartTimeUT to time()+LaunchCountdownCtr.
    StarshipAutopilotMFD["DisplayFlightStatus"]("Countdown").
    wait LaunchCountdownCtr.
    set BurnStartTimeUT to time(0).
    StarshipAutopilotMFD["DisplayFlightStatus"]("").
  }

local function SecondsUntilNextSyncPeriod
  {
// Return the number of seconds until the start of the next
// specified synchronisation period.
// Notes:
//    - Eg synchronise to next 30 second, etc. 
//    -
// Todo:
//    - This method is clunky and it is easy to miss the next
//      period, think about a better method.
//		- In practive the sychronisation is a little off eg 0.1 seconds.
//      Think about whether it can be improved.
//    -
    parameter period.

		local SecondsRemainingInPeriod to
			period-mod(floor(time:seconds),period).

    return SecondsRemainingInPeriod.
	}

local function SetMFD
  {
// Set the Multi-function Display.
// Notes:
//    -
// Todo:
//    -
    clearScreen.
    set terminal:width to MFDWidth.
    set terminal:height to MFDHeight.
    StarshipAutopilotMFD["DisplayLabels"](ship:name).
  }

local function CreateMFDRefreshTrigger
  {
// Create a trigger to refresh the the Multi-function Display periodically.
// Notes:
//		- Experimental. I have no idea what the physics tick cost will be.
//    -
// Todo:
//		- Try to figure out how often this needs to run.
//    -
    local RefreshInterval to 0.1.
    local NextMFDRefreshTime to time:seconds.
    when NextMFDRefreshTime < time:seconds
    then
      {
        StarshipAutopilotMFD["DisplayRefresh"]
         (
          ship:altitude,
          alt:radar,
          LandingGeo:distance,
          LandingGeo:altitudeposition(ship:altitude):mag,
          StoppingDistance,
          ship:verticalspeed,
          VerticalSpeedPID:setpoint,
          ship:apoapsis,
          ship:periapsis,
          ship:orbit:eccentricity,
          BurnStartTimeUT:seconds,
          time():seconds
         ).
        set NextMFDRefreshTime to NextMFDRefreshTime+RefreshInterval.
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
    if AutopilotMode = "HIGHALTITUDETEST"
      {
        if ship:status <> "PRELAUNCH"
        and ship:status <> "LANDED"
          {
            StarshipAutopilotMFD["DisplayError"]("Vessel is in flight or has splashed down").
            set FatalError to true.
          }
      }
    else
    if AutopilotMode = "RETURNTOLAUNCHSITE"
      {
        if ship:status <> "PRELAUNCH"
        and ship:status <> "LANDED"
        and ship:status <> "FLYING"
        and ship:status <> "SUB_ORBITAL"
          {
            StarshipAutopilotMFD["DisplayError"]("Vessel status"+" "+ship:status+ " is invalid").
            set FatalError to true.
          }
      }
    else
      {
        StarshipAutopilotMFD["DisplayError"]("Autopilot Mode parameter is invalid").
        set FatalError to true.
      }.
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
  set LandingSpotIndicatorRefreshTriggerActive to false.
  unlock throttle.
  unlock steering.
  wait 0.
}

local function CalcStoppingDistance
  {
// Calculate the estimated stopping distance.
// Notes:
//    - This estimating method does not take into account things like
//      inactive engines, engine flameouts etc. But it should not
//      matter as long as it is used in the correct context.
//    -
// Todo:
//    -
//    
    local grav to ship:body:mu/(ship:body:radius+ship:altitude)^2.
    local MaxDeceleration to
      ship:availableThrust/ship:mass-grav.
    return ship:verticalSpeed^2/(2*MaxDeceleration).
  }

local function CreateLandingSpotIndicator
  {
// Create an indicator to show where the predicted landing spot is.
// Notes:
//    - The indicator will refresh automatically.
//    - The predicted landing spot is the intersection of the
//      surface velocity vector and the surface.
//    - The position of the indicator is set above any terrain covering the landing spot
//      to avoid getting clipped. 
//    - The arrows might look strange from a distance, they don't
//      appear to scale very well.
//    - The arrows might still get clipped by the terrain despite their height
//      above the terrain.
//    - Experimental. I have no idea what the physics tick cost will be.
//    -
// Todo:
//    - The north, south,east,west are only working because the KSC is
//      near the equator.
//    - Investigate the flickering. It might be related to how far
//      from the vessel the indicator is. 
//    - Think some more about calculating the predicted landing spot:
//      Which is the best plane to use to calculate the intersection?
//      A sea-level plane ignores the terrain etc.
//    - Add scaling so the indicator can be seen from a distance.
//    - 

    local ArrowLength to 1000.
    local IndicatorHeight to 10.  // Indicator height above the terrain.
    local ArrowGap to 20.     // Arrow head gap from landing spot.
    local ArrowWidth to 0.1.
    local ArrowColour to red.
    local RefreshInterval to 1.
    local NextRefreshTime to time:seconds.
    local IndicatorPos to 0.

// Set up the land spot indicator arrows.
    set NorthVD:colour to ArrowColour.
    set NorthVD:width to ArrowWidth.
    set NorthVD:label to "POI".
    set NorthVD:show to false.
    set NorthVD:vec to v(10,10,10).

// Create the trigger to refresh the position of the indicator.
// If there is no prediction then do not refresh the last drawn position?
    when time:seconds >= NextRefreshTime
    then
      {
        local temp1 to PredictedLandingSpot.
        if temp1 <> V(0,0,0)
          {
            local temp2 to ship:body:geopositionof(PredictedLandingSpot).
            set IndicatorPos to
              temp2:altitudeposition(temp2:terrainheight+IndicatorHeight).
            set NorthVD:start to ship:position.
            set NorthVD:vec to IndicatorPos.
            set NorthVD:show to true.
          }
        set NextRefreshTime to NextRefreshTime+RefreshInterval.
        return LandingSpotIndicatorRefreshTriggerActive.
      }
  }

local function SetAirbrakeControlSurfaces
  {
// Notes:
//    -
// Todo:
//    -
	parameter value is false.
	
	local ab is ship:partsnamed("airbrake1").
	for p in ab
    {
		  local m is p:getmodule("moduleaerosurface").
		  m:setfield("pitch", value).
		  m:setfield("yaw", value).
	}
}

local function SetFlapAngle
  {
// Set the angle of the flap.
// Notes:
//    - 0 degrees:    Fully retracted.
//    - 90 degrees:   Fully extended.
// Todo:
//    - 
    parameter FlapPart.
    parameter angle.

    FlapPart:getmodule("ModuleRoboticServoHinge"):
      setfield("Target Angle",angle+90).
  }

local function TestFlaps
  {
// Test the flaps by moving them one at a time.
// Notes:
//    -
// Todo:
//    -
    StarshipAutopilotMFD["DisplayDiagnostic"]("Flap Test: Moving forward port flap","").
    SetFlapAngle(ForwardPortFlap,0).
    wait 2.
    SetFlapAngle(ForwardPortFlap,90).
    wait 2.
    StarshipAutopilotMFD["DisplayDiagnostic"]("Flap Test: Moving forward starboard flap","").
    SetFlapAngle(ForwardStarFlap,0).
    wait 2.
    SetFlapAngle(ForwardStarFlap,90).
    wait 2.
    StarshipAutopilotMFD["DisplayDiagnostic"]("Flap Test: Moving aft port flap","").
    SetFlapAngle(AftPortFlap,0).
    wait 2.
    SetFlapAngle(AftPortFlap,90).
    wait 2.
    StarshipAutopilotMFD["DisplayDiagnostic"]("Flap Test: Moving aft starboard flap","").
    SetFlapAngle(AftStarFlap,0).
    wait 2.
    SetFlapAngle(AftStarFlap,90).
    wait 2.
    StarshipAutopilotMFD["DisplayDiagnostic"]("","").
  }

local function DisplayFlapDiagnostics
  {
// Display diagnostics for the flaps.
// Notes:
//    -
// Todo:
//    -
  local Diag1 to
    "P: "+round(PitchPID:output,2)+" "+round(PitchPID:error,2)
    +" Y: "+round(YawPID:output,2)+" "+round(YawPID:error,2)
    +" R: "+round(RollPID:output,2)+" "+round(RollPID:error,2).
  local Diag2 to
    "Flaps: "
    +"FP: "+round(ForwardPortFlapAng,1)
    +" FS: "+round(ForwardStarFlapAng,1)
    +" AP: "+round(AftPortFlapAng,1)
    +" AS: "+round(AftStarFlapAng,1).
  StarshipAutopilotMFD["DisplayDiagnostic"](Diag1,Diag2).
  }

local function RaiseLandingGear
  {
// Raise the landing gear.
// Notes:
//    -
// Todo:
//    -
    for p in GearPartList
      {
	      local m is p:getmodule("ModuleRoboticServoPiston").
		    m:setfield("Target Extension",0).
	    }
  }

local function LowerLandingGear
  {
// Lower the landing gear.
// Notes:
//    -
// Todo:
//    -
    for p in GearPartList
      {
	      local m is p:getmodule("ModuleRoboticServoPiston").
		    m:setfield("Target Extension",1).
	    }
  }