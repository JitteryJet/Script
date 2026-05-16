// Name: LandNewGlennBooster
// Author: JitteryJet
// Version: V01
// kOS Version: 1.4.0.0
// KSP Version: 1.12.5
// Description:
//    Land a Blue Origins New Glenn Booster
//
// Assumptions:
//    - The vessel is roughly like a Blue Origins New Glenn booster.
//      Other vessels can be used, but results may be unpredictable.
//    - No staging is required after booster separation.
//    -
//
// Notes:
//    - The guidance is OK but not miraculous.
//      The trajectory of the booster after separation must still
//      land near the landing spot even without the booster guidance.
//      Downrange and crossrange course correction is limited.
//    - This script finds transfer orbits by using a Lambert Solver.
//      Short Way and Long Way elliptical transfer orbits are handled.
//      Parabolic and hyperbolic transfer orbits are not handled.
//    - The script does not compensate for drag. The scripts works by
//      minimising drag.
//    - ### IMPORTANT ###
//      This script is sensitive to atmospheric drag and the spin of the body
//      which can move the booster off a good glide path and make course-corrections
//      harder. Boostbacks that minimise drag by coming almost straight down work best.
//      A booster that previously worked can stop working after minor changes to the booster.
//      If your booster keeps missing the landing spot or flipping
//      during the suicide burn, try switching drag off and adjusting
//      landing height and landing speed to see if that works - if it
//      doesn't then try adjusting the booster trajectory.
//    -
//
//    - Orbits to keep track of:
//        Departure             - Ship's current orbit.
//        Transfer              - Ship's transfer orbit to the landing spot.      
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
//        v is speed (or velocity if a vector).
//
// Todo:
//    - Improve just about everything.
//
// Update History:
//    15/05/2026 V01  - Created.
//                    -
//
@lazyglobal off.
// Increase IPU value to speed up scripts with a lot of calculations
// if the CPU and graphic card are good. Default is around 200.
// Max is around 2000.
set config:ipu to 2000.

// Parameter descriptions.        
//    LandingGeo                      GeoPosition of the landing spot.
//    AimHeightKm                     Height (km) above the landing spot
//                                    where the booster transfer orbit ends.
//                                    Increase this value to provide more headroom
//                                    if the booster falls short of the landing spot.
//                                    Choose a value high enough so the transfer orbit will clear the
//                                    terrain between booster separation and the landing spot.
//    LandingHeight                   Height above ground (m) to ready vessel for landing.
//                                    Choose a value to allow the landing legs to deploy.
//    LandingSpeed                    Landing speed (m/s).                            
//	  WarpType	  					          "PHYSICS","RAILS" or "NOWARP".
//    ShowArrows                      Show position vector arrows for debugging.
//                                    "SHOW" or "NOSHOW".
//    

parameter LandingGeo to LatLng(0,0).
parameter AimHeightKm to 0.
parameter LandingHeight to 150.
parameter LandingSpeed to 5.
parameter WarpType to "NOWARP".
parameter ShowArrows to "NOSHOW".

// Load in functions from the library.
runoncepath("LandNewGlennBoosterMFD V01").
runoncepath("Delta-vFunctions V05").
runoncePath("LambertSolverFunctions V03").

local AimHeight to AimHeightKm*1000.
local NextMFDRefreshTime to time:seconds.
local MFDRefreshInterval to 0.1.
local MFDRefreshTriggerActive to true.
local tManeuverStartTStmp to timestamp(0.0).
local FatalError to false.
local VeryBigNumber to 3.402823E+38.
local DiagnosticMN to 0.

// Nominal pressure limit that defines the endoatmospheric/
// exoatmospheric boundary where I no longer care about
// atmospheric drag.   
local DragSensibleAtmosphereLimit
  to bodyAtmosphere("KERBIN"):altitudepressure(33000).

local lock HeightAGL TO ship:altitude-ship:geoposition:terrainheight.

local tArrTStmp to timestamp(0.0).

// Log file for debugging.
local LogFilename to kuniverse:realtime:tostring+".txt".

// Display arrows for debugging.
local P2Arrow to
  vecdraw(V(0,0,0),V(0,0,0),yellow,"P2",1.0,false,0.01,true,false).
local LandingSpotArrow to
  vecdraw(V(0,0,0),V(0,0,0),red,"LS",1.0,false,0.01,true,false).

sas off.
rcs off.
legs off.
set ship:control:mainthrottle to 0.
clearvecdraws().
SetMFD().
CheckForErrorsAndWarnings().
wait 0.
if not FatalError
  {
    DoCoasting().
    DoReentryFlipManeuver().
    DoReentryManeuver().
    DoLandingManeuverLambert().
    DoLandedShutdown().
  }
MFDFunctions["DisplayFlightStatus"]("Finished").
RemoveLocksAndTriggers().

local function DoCoasting
  {
// Coast to the apoapsis after booster separation.
// Notes:
//    - It usually works out better if the launch
//      trajectory includes a coast out of the atmosphere
//      before flipping the booster as flipping using only RCS
//      can be slow.
// Todo:
//    -

    MFDFunctions["DisplayFlightstatus"]("Coasting").

    wait until ship:altitude > ship:body:atm:height.

// Only PHYSICS time warping as the flip won't work using
// RAILS time warping.
    if WarpType <> "NOWARP"
      {
        set kuniverse:timewarp:mode to "PHYSICS".
        set kuniverse:timewarp:warp to 3.
      }
    wait eta:apoapsis.
  }

local function DoReentryFlipManeuver
  {
// Do the booster flip maneuver prior to atmospheric reentry.
// Notes:
//    - Plan the launch trajectory to avoid flipping
//      the booster in the atmosphere.
//    -
// Todo:
//    -

    MFDFunctions["DisplayFlightstatus"]("Reentry flip").
    lock steering to lookDirUp (-ship:velocity:orbit,ship:up:forevector).
    rcs on.
    wait until ship:altitude < ship:body:atm:height.
    kuniverse:timewarp:cancelwarp().
//    rcs off.
//    unlock steering.
  }

local function DoReentryManeuver
  {
// Do the booster reentry maneuver.
// Notes:
//    - A booster reentry is not required in KSP, this
//      maneuver is included in this script for realism.
//    - What this maneuver does is provide a course-
//      correction. The course-correction is pretty good
//      and provides downrange and crossrange corrections
//      by using a Lambert Solver and a closed feedback loop.     
//    -
// Todo:
//    - Find a way to stop the booster flipping during the burn
//      that happens under some situations.
//    - 

    local tDepTStmp to timestamp(0.0).
    local r1 to 0.                          // Orbit radius of Point1.
    local r2 to 0.                          // Orbit radius of Point2.
    local chord to 0.                       // Chord Point1-Point2.
    local mu to 0.                          // Standard Gravitational Parameter
    local tParabolicTransTSpan              // Defines a parabolic orbit.
      to timespan(0.0).
    local TransAng to 0.0.                  // Transfer angle.
    local r1Vec to v(0,0,0).
    local r2Vec to v(0,0,0).
    local vTransDvVec to v(0,0,0).
    local aTrans to 0.0.
    local aMinSOETrans to 0.0.
    local tShortWayOrbitMaxTSpan to timespan(0.0).
    local SteeringDir to 0.
    local tTransTSpan to timespan(0.0).
    local ShortWayOrbit to false.
    local finished to false.
    local vPreviousDv to 99999.9.
    local ThrottleSet to 0.0.
    local SteeringVec to v(0,0,0).

    MFDFunctions["DisplayFlightStatus"]("Reentry burn").

    set SteeringVec to -ship:velocity:orbit.
    set SteeringDir to lookDirUp(SteeringVec,ship:up:forevector).
    rcs on.
    lock steering to SteeringDir.
    lock throttle to ThrottleSet.
    set mu to ship:body:mu.
    set tDepTStmp to timestamp().

// The maneuver transfer time has to be larger than the current transfer
// time to prevent the booster flipping during the burn.
    set tTransTSpan to timespan(CalcTimeToImpactTerrain()*1.1).
    set tArrTStmp to tDepTStmp+tTransTSpan.
    until finished
      {
        set tTransTSpan to tArrTStmp-tDepTStmp.
        set r1Vec to ship:position-ship:body:position.
        set r2Vec to
          CalcGeoPositionAt(LandingGeo,AimHeight+LandingHeight,tArrTStmp)-ship:body:position.
        set TransAng to vang(r1Vec,r2Vec).
        set chord to (r2Vec-r1Vec):mag.
        set r1 to r1Vec:mag.
        set r2 to r2Vec:mag.
        set tParabolicTransTSpan to
          CalcParabolicTransferTimeLambert(r1,r2,chord,mu,TransAng).
            MFDFunctions["DisplayDiagnostic"]
          ("tTrans "+tTransTSpan,"tPara "+tParabolicTransTSpan).
        if tTransTSpan > tParabolicTransTSpan
          {
            set aMinSOETrans to (r1+r2+chord)/4.
            set tShortWayOrbitMaxTSpan to
              CalcTransferTimeLambert(r1,r2,chord,aMinSOETrans,mu,TransAng,true).
            if tTransTSpan < tShortWayOrbitMaxTSpan
              set ShortWayOrbit to true.
            else
              set ShortWayOrbit to false.
            set aTrans to CalcSMALambert(tTransTSpan,r1,r2,chord,mu,TransAng).
            set vTransDvVec to
              (CalcTransferDepVelLambertVec(r1Vec,r2Vec,aTrans,mu,TransAng,ShortWayOrbit)
                -ship:velocity:orbit).
            MFDFunctions["DisplaySearchResults"]
              (
                tDepTStmp,
                tTransTSpan,
                aTrans,
                vTransDvVec:mag,
                ShortWayOrbit
              ).
//            DisplayDiagnosticMN(vTransDvVec,tDepTStmp).
//            kuniverse:pause().
            if vTransDvVec:mag < vPreviousDv
              or vTransDvVec:mag > 10
              {
                set ThrottleSet to 1.0.
                if vTransDvVec:mag > 10
                  set SteeringDir to lookDirUp(vTransDvVec,ship:up:forevector).
                set vPreviousDv to vTransDvVec:mag.
              }
            else
              {
                set ThrottleSet to 0.0.
                set finished to true.
              }
          }
        else
          {
            MFDFunctions["DisplayError"]("Parabolic or hyperbolic orbits are not supported").
//            set ThrottleSet to 0.0.
//            set finished to true.
          }
        wait 0. // Force at least one physics frame per loop iteration.
        set tDepTStmp to timestamp().
      }
    unlock throttle.
    unlock steering.
    rcs off.
  }

local function DoLandingManeuverLambert
  {
// Do the landing maneuver to slow down and land.
// Notes:
//    - The sequence of events is:
//      - Coast until atmospheric drag becomes significant.
//      - Adjust attitude to line up with the calculated
//        trajectory.
//      - Do the suicide burn. This burn also provides
//        a lot of the course-correction.
//      - Once the speed drops start a "hover burn" which is
//        really a speed-controlled vertical descent with a
//        small amount of course-correction.
//      - When the landing height is reached prepare for
//        landing. This includes a speed-controlled vertical
//        descent with a tiny amount of course-correction.
//
//    - IMPORTANT! The course-correcting method used requires
//      a strong velocity vector to avoid the booster
//      flipping as it slows. Atmospheric drag is a problem
//      with a booster as it is long and almost empty of fuel.
//
//    - IMPORTANT! The course-correction method used is
//      OK but not miraculous. On the final part of the descent,
//      the vessel has to be almost vertical which depends on a
//      number of factors.
//
//    - The braking burns course-correct by continuously
//      calculating a trajectory toward the landing spot.
//      Air resistance and fuel consumption during landing
//      make an efficient suicide burn a challenge.
//      Experiments have shown this code gives good results.
//    -
// Todo:
//    - Find a way to stop the booster flipping during the burn
//      that happens under some situations.
//    -

    local MinHoverBurnSpeed to 50.

    local SuicideBurn to false.
    local HoverBurn to false.
    local LandingBurn to false.
    local r1 to 0.
    local r2 to 0.
    local chord to 0.
    local TransAng to 0.
    local ThrottleSet to 0.0.
    local tParabolicTransTSpan to timespan(0.0).
    local aMinSOETrans to 0.
    local tShortwayOrbitMaxTSpan to timespan(0.0).
    local finished to false.
    local vTransVec to v(0,0,0).
    local vTransDvVec to v(0,0,0).
    local r1Vec to v(0,0,0).
    local r2Vec to v(0,0,0).
    local LSVec to v(0,0,0).
    local aTrans to 0.0.
    local SteeringVec to v(0,0,0).
    local tTransTSpan to timespan(0.0).
    local tDepTStmp to timestamp(0.0).
    local ShortWayOrbit to false.
    local EndHeight to 0.0.

// PID controller to regulate the speed
// by controlling the throttle.
    local SpeedPID to PIDLoop().
    set SpeedPID:kp to 0.1.
    set SpeedPID:ki to 0.1.
    set SpeedPID:kd to 0.01.
    set SpeedPID:minoutput to 0.
    set SpeedPID:maxoutput to 1.

// Redefine the "height above the ground" from the COM of the ship
// to the bottom of the vessel. This was delayed until now
// so the ship configuration and bounding box are in their final
// state (ignoring any landing legs deployment).
    local BBox to ship:bounds.
    local lock HeightAGLBottom to BBox:bottomaltradar.  
    wait 0.

    MFDFunctions["DisplayFlightstatus"]("Descent").

    set SteeringVec to -ship:velocity:surface.
    lock Steering to lookDirUp(SteeringVec,ship:up:forevector).
    set ThrottleSet to 0.
    lock throttle to ThrottleSet.
    set EndHeight to AimHeight+LandingHeight.
    rcs on.

// Wait until atmospheric drag becomes significant.
    until ship:body:atm:altitudepressure(ship:altitude) > DragSensibleAtmosphereLimit
      {
        set SteeringVec to -ship:velocity:orbit.
        wait 0.
      }

    MFDFunctions["DisplayFlightstatus"]("Attitude trim").

    set tDepTStmp to timestamp().
    set tTransTSpan to tArrTStmp-tDepTStmp.
    set vTransVec to CalcGeoPositionAt(LandingGeo,EndHeight,tArrTStmp).

// The booster strakes have to be perpendicular to the
// direction of the landing spot to stop small amounts
// of lift from the strakes pushing the booster to the side. 
    lock Steering to lookDirUp(SteeringVec,vTransVec).

    until finished
      {
        set r1Vec to ship:position-ship:body:position.
        set r2Vec to CalcGeoPositionAt(LandingGeo,EndHeight,tArrTStmp)-ship:body:position.
        set TransAng to vang(r1Vec,r2Vec).
        set r1 to r1Vec:mag.
        set r2 to r2Vec:mag.
        set chord to (r2Vec-r1Vec):mag.
        set aTrans to CalcSMALambert(tTransTSpan,r1,r2,chord,ship:body:mu,TransAng).
        set tParabolicTransTSpan to
          CalcParabolicTransferTimeLambert(r1,r2,chord,ship:body:mu,TransAng).
        set aMinSOETrans to (r1+r2+chord)/4.
        set tShortWayOrbitMaxTSpan to
          CalcTransferTimeLambert(r1,r2,chord,aMinSOETrans,ship:body:mu,TransAng,true).
        if tTransTSpan < tShortWayOrbitMaxTSpan
          set ShortWayOrbit to true.
        else
          set ShortWayOrbit to false.
        if tTransTSpan > tParabolicTransTSpan
          {
            set vTransVec to
              CalcTransferDepVelLambertVec
                (
                  r1Vec,
                  r2Vec,
                  aTrans,
                  ship:body:mu,
                  TransAng,
                  ShortWayOrbit
                ).
          }
        else
          {
            MFDFunctions["DisplayError"]("Parabolic or hyperbolic orbits are not supported").
            print 0/0. // Terminate the program.
          }
        set vTransDvVec to vTransVec-ship:velocity:orbit.
        set SteeringVec to vTransDvVec.
        MFDFunctions["DisplaySearchResults"]
          (
            tDepTStmp,
            tTransTSpan,
            aTrans,
            vTransDvVec:mag,
            ShortWayOrbit
          ).
//        DisplayDiagnosticMN(vTransDvVec,tDepTStmp).
        MFDFunctions["DisplayDiagnostic"]
          (tParabolicTransTSpan+" "
          +tShortWayOrbitMaxTSpan,
          +round(vTransVec:mag,2)).

// Todo: document assumptions here.

// Test for start of Suicide burn.
        if not SuicideBurn
          and not HoverBurn
          and not LandingBurn
          and CalcStoppingDistance(ship:velocity:surface)
                > CalcGeoPositionAt(LandingGeo,0,tArrTStmp):mag
          {
            set SuicideBurn to true.
            MFDFunctions["DisplayFlightstatus"]("Suicide burn").
          }

// Test for start of Hover burn.
        if not HoverBurn
          and SuicideBurn
          and ship:verticalspeed > -MinHoverBurnSpeed
          {
            set HoverBurn to true.
            set SuicideBurn to false.
            MFDFunctions["DisplayFlightstatus"]("Hover burn").
            set SpeedPID:setpoint to -MinHoverBurnSpeed.
            set EndHeight to LandingHeight.    
          }

// Test for start of Landing burn.
        if not LandingBurn
          and HoverBurn
          and HeightAGLBottom < LandingHeight
          {
            set LandingBurn to true.
            set HoverBurn to false.
            MFDFunctions["DisplayFlightstatus"]("Landing burn").
            set SpeedPID:setpoint to -LandingSpeed.
          }

// Actions for each type of burn.
        if SuicideBurn
          {
            set ThrottleSet to 1.   
          }
        if HoverBurn
          {
            set ThrottleSet to SpeedPID:update(time:seconds,ship:verticalspeed).
          }
        if LandingBurn
          {
            set SteeringVec to
              ship:up:forevector*LandingSpeed-ship:velocity:surface/10.
            set ThrottleSet to SpeedPID:update(time:seconds,ship:verticalspeed).
            gear on.
            if ship:status = "LANDED"
              {
                set LandingBurn to false.
                set finished to true.
              }
          }

// Show arrows diagnostic.
        if ShowArrows = "SHOW"
          {
            set P2Arrow:start to (r2Vec*1.1+ship:body:position).
            set P2Arrow:vec to -r2Vec*0.1.
            set P2Arrow:show to true.
            set LSVec to CalcGeoPositionAt(LandingGeo,EndHeight,tDepTStmp)-ship:body:position.
            set LandingSpotArrow:start to (1.1*LSVec+ship:body:position).
            set LandingSpotArrow:vec to -LSVec*0.1.
            set LandingSpotArrow:show to true.
          }

        wait 0. // Force at least one physics frame per loop iteration.

// Some program "tuning" which I have still not eliminated.
// The correct value will require experimentation.
// The biggest problem is the booster flipping during burns.
        set tTransTSpan to timespan(CalcTimeToImpactTerrain()*1.1).
        set tDepTStmp to timestamp().
        set tArrTStmp to tDepTStmp+tTransTSpan.
      }
    rcs off.
    set P2Arrow:show to false.
    set LandingSpotArrow:show to false.
  }

local function DoLandedShutdown
  {
// Do the shutdown after landing.
// Notes:
//    -
// Todo:
//    - 
    MFDFunctions["DisplayFlightstatus"]("Landed").
    unlock throttle.

// Stabilize the vessel.
    lock steering to lookdirup(ship:up:forevector,ship:facing:topvector).
    rcs on.
    wait 10.
    rcs off.
    unlock steering.
  }

local function CalcGeoPositionAt
  {
// Calculate the position vector of the spot above (or below)
// a geographical position at some time in the future.
// Notes:
//    -
// Todo:
//    -
    parameter Geo.
    parameter AboveHeight.
    parameter TStmp.

    local FutureLng to
      Geo:lng+((TStmp-timestamp()):seconds/ship:body:rotationperiod)*360.

    local FuturePositionVec to
      latlng(Geo:lat,FutureLng):altitudeposition(Geo:terrainheight+AboveHeight).

    return FuturePositionVec.
  }

local function CalcGeoVelocityOrbitAt
  {
// Calculate the velocity vector of the spot above (or below)
// a geographical position at some time in the future.
// Notes:
//    -
// Todo:
//    -
    parameter Geo.
    parameter AboveHeight.
    parameter TStmp.

    local FutureLng to
      Geo:lng+((TStmp-timestamp()):seconds/ship:body:rotationperiod)*360.

    local FutureVelocityOrbitVec to
      latlng(Geo:lat,FutureLng):altitudevelocity(Geo:terrainheight+AboveHeight):orbit.

    return FutureVelocityOrbitVec.
  }

local function CalcStoppingDistance
  {
// Calculate the stopping distance for a vessel moving in
// a straight line.
// Notes:
//    - This is a hack.
//    - The stopping distance is an instantaneous calculation
//      based on the state of the vessel at that time.
//      In practice it gives a ballpark figure only.
//    - Fuel consumption is ignored.
//    - Air resistance is ignored.
//    - 
// Todo:
//    -
//   
    parameter vVec to v(0,0,0).

    local ShipAcc to 0.
    local StoppingDistance to 0.

    set ShipAcc to ship:availableThrust/ship:mass.
    set StoppingDistance to vVec:mag^2/(2*ShipAcc).
    return StoppingDistance.
  }

local function CalcTimeToImpactTerrain
  {
// Calculate the time to impact the terrain.
// Notes:
//    - Return -1 if there is no predicted impact in one orbit.
//    - Keep in mind these are orbit PREDICTIONS that assumes
//      the "on rails" calculations and any maneuver nodes work
//      perfectly. In reality there will be some error. In an
//      atmosphere there could be a LOT of error. 
//    -
// Todo:
//    - More testing.
//    -

    local finished to false.
    local tTSTMP to timestamp(0.0).
    local t0TSTMP to timestamp().
    local t to 0.0.
    local tStep to 1.0.
    local PosVec to v(0,0,0).
    local PosGeo to latlng(0,0).
    local PosAltitude to 0.0.
    local tOneOrbitTSTMP to timestamp().

    set tOneOrbitTSTMP to t0TSTMP+ship:obt:period.

    until finished
      {
        set tTSTMP to t0TSTMP+t.
        set PosVec to positionat(ship,tTSTMP).
        set PosGeo to CalcFutureGroundPosition(tTSTMP).
        set PosAltitude to
          (PosVec-ship:body:position):mag-ship:body:radius.
        if PosAltitude <= PosGeo:terrainheight
            set finished to true.
        else
          {
            set t to t+tStep.
            if tTStmp > tOneOrbitTSTMP
              {
                set t to -1.
                set finished to true.
              }
          }
      }
    return t.
  }

local function CalcFutureGroundPosition
  {	
// Calculate the ground position of the ship at a time in the future.
// Notes:
//    - Takes planetary rotation into account.
//    -
// Todo:
//    - More testing.
//    -

	  parameter FutureTStmp.

    local TimeTSpan to FutureTStmp-timestamp().
    local LocalBody to ship:body.
	  local PosVec to positionat(ship,FutureTStmp).
    local PosGeo to LocalBody:geopositionof(PosVec).

// Calculate the number of radians the body will rotate in one second
// (negative if rotating counter clockwise).
	  local RotationalVel to
      vdot(LocalBody:north:forevector,LocalBody:angularvel).

	  local LNGShift to RotationalVel*TimeTSpan:seconds*constant:radtodeg.
	  local NewLNG to mod(PosGeo:LNG+LNGShift,360).
	  if NewLNG < -180
      set NewLNG to NewLNG+360.
    else
	    if NewLNG > 180
        set NewLNG to NewLNG-360.

	  return latlng(PosGeo:LAT,NewLNG).
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
// Increase the terminal width if you need to
// read the debug messages displayed on the screen.
//    set terminal:width to 100.
    set terminal:height to 27.
    MFDFunctions["DisplayLabels"]
      (
        ship:name,
        LandingGeo:lat,
        LandingGeo:lng,
        AimHeight,
        LandingHeight,
        LandingSpeed
      ).
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
//    -
    when (NextMFDRefreshTime < time:seconds)
    then
      {
        MFDFunctions["DisplayRefresh"]
         (
          ship:obt:apoapsis,
          ship:obt:periapsis,
          ship:obt:inclination,
          ship:obt:eccentricity,
          ship:verticalspeed,
          ship:altitude,
          HeightAGL,
          tManeuverStartTStmp,
          timestamp()
         ).
        set NextMFDRefreshTime to NextMFDRefreshTime+MFDRefreshInterval.
        return MFDRefreshTriggerActive.
      }
  }

local function CheckForErrorsAndWarnings
  {
// Check for errors and warnings.
// Notes:
//    - I picked "reasonable" values to check for.
// Todo:
//    - Add warning about atmospheres.

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

// Wait long enough so the triggers have finished
// firing before deallocating anything the triggers
// use.
    wait MFDRefreshInterval.

// Remove any global variables that might
// cause problems if they hang around
// for too long.
    unset MFDFunctions.

// Unlock the throttle and steering controls
// used by the Player.
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

local function DisplayDiagnosticMN
  {
// Display a KSP maneuver node as a diagnostic.
// Notes:
//    - The actual orbit will closely match this node
//      after the maneuver burn is done.
//    - Keep in mind running this diagnostic will
//      slow down the search, increasing the time
//      allowed for the search may be necessary.
//    - If you fiddle around with this code only display
//      a node for a short period of time then remove it
//      as a node on the flightpath of the ship affects the
//      orbit prediction commands such as positionat and
//      velocityat.
//    -
// Todo:
//    -
//
    parameter MNVec.
    parameter MNTStmp.

    set DiagnosticMN to CreateNodeFromVec(MNVec,MNTStmp).
    add DiagnosticMN.
    wait 0.
//    kuniverse:pause().
    remove DiagnosticMN.
    wait 0.
  }