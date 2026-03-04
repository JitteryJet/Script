// Name: LandStarshipBooster
// Author: JitteryJet
// Version: V03
// kOS Version: 1.4.0.0
// KSP Version: 1.12.5
// Description:
//    Land a SpaceX Starship Booster
//
// Assumptions:
//    - The vessel is roughly like a SpaceX Starship booster.
//      Other vessels can be used, but results may be unpredictable.
//    - No staging is required.
//    -
//
// Notes:
//    - This script finds transfer orbits by using a Lambert Solver.
//      Short Way and Long Way elliptical transfer orbits are handled.
//      Parabolic and hyperbolic transfer orbits are not handled.
//    - ### IMPORTANT ###
//      This script is sensitive to atmospheric drag and the spin of the body
//      which can move the booster off a good glide path and make course-corrections
//      harder. Boostbacks that minimise drag by coming almost straight down work best.
//      A booster that previously worked can stop working after minor changes to the booster.
//      If your booster keeps missing the landing spot or flipping
//      during the suicide burn, try switching drag off and adjusting
//      landing height and landing speed to see if that works - if it
//      doesn't then try adjusting the boostback trajectory.
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
//    - Test with a SpaceX Falcon 9 booster.
//    - Add parameter to find transfer orbits with smaller delta-v burns
//      or longer transfer times.
//    - Search for boostback orbits with a high chance of making it back to
//      the landing spot.
//    - 
//
// Update History:
//    30/05/2023 V01  - Created.
//    01/12/2023 V02  - Added a better stopping distance calculation
//                      to the suicide burn. This reduces fuel requirements.
//                    - Many changes to the landing guidance.
//                    - Added "Long Way" transfer orbits.
//                    - Removed unused code.
//    24/11/2024 V03  - WIP
//                    - Renamed script to LandStarshipBooster.
//                    - Added changes for SpaceX Starship Flight Test 5,
//                      the first "Mechazilla" test flight.
//                    - Improved the landing guidance.
//                    -
//
@lazyglobal off.
// Increase IPU value to speed up scripts with a lot of calculations
// if the CPU and graphic card are good. Default is around 200.
// Max is around 2000.
set config:ipu to 2000.

// Parameter descriptions.        
//    LandingGeo                      GeoPosition of the landing spot.
//    BoostbackTransferDuration       Boostback transfer orbit duration (s).
//                                    Defines the 'shape' of the transfer
//                                    orbit.
//    BoostbackFlipDuration           Boostback flip duration (s).
//                                    How much time to spend flipping
//                                    the booster after stage separation.
//    CorrectionLeadDuration          Correction burn lead time (s).
//                                    How much time to allow searching
//                                    for and doing the correction burn.
//                                    Does not include steering time.
//    CorrectionSteeringDuration      Correction burn steering duration (s).
//                                    How much time to spend steering before
//                                    the correction burn.       
//    DescentHeightKm                 Height (km) above the landing spot
//                                    where the transfer orbit ends.
//                                    Increase this value to provide more headroom
//                                    if the vessel falls short of the landing spot.
//                                    Choose a value high enough so the transfer orbit will clear the
//                                    terrain between the departure point and the landing spot.
//    LandingHeight                   Height above ground to ready vessel for landing (m).
//                                    Choose a value to allow the landing legs to deploy.
//    LandingSpeed                    Landing speed (m/s).                            
//	  WarpType	  					          "PHYSICS","RAILS" or "NOWARP".
//    ShowArrows                      Show position vector arrows for debugging.
//                                    "SHOW" or "NOSHOW".
//    

parameter LandingGeo to LatLng(0,0).
parameter BoostbackOrbitDuration to 240.
parameter BoostbackFlipDuration to 15.
parameter CorrectionLeadDuration to 90.
parameter CorrectionSteeringDuration to 60.
parameter DescentHeightKm to 0.
parameter LandingHeight to 150.
parameter LandingSpeed to 5.
parameter WarpType to "NOWARP".
parameter ShowArrows to "NOSHOW".

// Load in functions from the library.
runoncepath("LandStarshipBoosterMFD V03").
runoncepath("Delta-vFunctions V05").
runOncePath("LambertSolverFunctions V02").

local DescentHeight to DescentHeightKm*1000.
local NextMFDRefreshTime to time:seconds.
local MFDRefreshInterval to 0.1.
local MFDRefreshTriggerActive to true.
local tManeuverStartTStmp to timestamp(0).
local FatalError to false.
local VeryBigNumber to 3.402823E+38.
local tBoostbackOrbitTSpan to timespan(0,0,0,0,BoostbackOrbitDuration).
local tBoostbackFlipTSpan to timespan(0,0,0,0,BoostbackFlipDuration).
local tCorrectionLeadTSpan to timespan(0,0,0,0,CorrectionLeadDuration).
local tCorrectionSteeringTSpan to timespan(0,0,0,0,CorrectionSteeringDuration).
local DiagnosticMN to 0.

// Nominal pressure limit that defines the endoatmospheric/
// exoatmospheric boundary where I no longer care about
// atmospheric drag.   
local DragSensibleAtmosphereLimit
  to bodyAtmosphere("KERBIN"):altitudepressure(33000).

local lock HeightAGL TO ship:altitude-ship:geoposition:terrainheight.

local tArrTStmp to timestamp(0).

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
brakes off.
set ship:control:mainthrottle to 0.
clearvecdraws().
SetMFD().
CheckForErrorsAndWarnings().
wait 0.
if not FatalError
  {
    DoBoostbackFlipManeuver().
    DoBoostbackManeuver().
    DoReentryFlipManeuver().
    DoLandingManeuverLambert().
    DoLandedShutdown().
  }
MFDFunctions["DisplayFlightStatus"]("Finished").
RemoveLocksAndTriggers().

local function DoBoostbackFlipManeuver
  {
// Do the boostback flip maneuver.
// Notes:
//    -
// Todo:
//    -
    rcs off.

// Using thrust vectoring wastes some fuel but it works better
// than the RCS.
    lock steering to lookDirUp(-ship:velocity:orbit,ship:up:forevector).
    MFDFunctions["DisplayFlightStatus"]("Boostback flip").
    lock throttle to 0.1.
    wait tBoostbackFlipTSpan:seconds.
    lock throttle to 0.
  }

local function DoBoostbackManeuver
  {
// Do the boostback maneuver.
// Notes:
//    - A boostback burn with feedback steering is used instead of a fixed burn
//      from a point of impulse. This allows the burn to be calculated and
//      started quickly - it looks better.      
//    -
// Todo:
//    - Fix up code that does not take into account the altitude of
//      the burn due to engine efficiencies at that altitude.
//    - 
    local tDepTStmp to timestamp(0).
    local r1 to 0.                          // Orbit radius of Point1.
    local r2 to 0.                          // Orbit radius of Point2.
    local chord to 0.                       // Chord Point1-Point2.
    local mu to 0.                          // Standard Gravitational Parameter
    local tParabolicTransTSpan              // Defines a parabolic orbit.
      to timespan(0).
    local TransAng to 0.                    // Transfer angle.
    local r1Vec to v(0,0,0).
    local r2Vec to v(0,0,0).
    local vTransDvVec to v(0,0,0).
    local aTrans to 0.0.
    local aMinSOETrans to 0.0.
    local tShortWayOrbitMaxTSpan to timespan(0).
    local SteeringDir to 0.
    local tTransTSpan to timespan(0).
    local ShortWayOrbit to false.
    local finished to false.
    local vPreviousDv to 99999.9.
    local ThrottleSet to 0.0.

    set SteeringDir to lookDirUp(-ship:velocity:orbit,ship:up:forevector).
    lock steering to SteeringDir.
    lock throttle to ThrottleSet.
    set mu to ship:body:mu.
    set tTransTSpan to tBoostbackOrbitTSpan.
    set tDepTStmp to timestamp().
    set tArrTStmp to tDepTStmp+tTransTSpan.
    set r2Vec to
      CalcGeoPositionAt(LandingGeo,DescentHeight+LandingHeight,tArrTStmp)-ship:body:position. #### fix this!!! Not invariant!!! #####
    set r2 to r2Vec:mag.
    MFDFunctions["DisplayFlightStatus"]("Boostback burn").
    until finished
      {
        set tDepTStmp to timestamp().
        set tTransTSpan to tArrTStmp-tDepTStmp.
        set r1Vec to ship:position-ship:body:position.
        set TransAng to vang(r1Vec,r2Vec).
        set chord to (r2Vec-r1Vec):mag.
        set r1 to r1Vec:mag.
        set tParabolicTransTSpan to
          CalcParabolicTransferTimeLambert(r1,r2,chord,mu,TransAng).
        if tTransTSpan > tParabolicTransTSpan
          {
            set aMinSOETrans to (r1+r2+chord)/4.
            set tShortWayOrbitMaxTSpan to CalcTransferTimeLambert(r1,r2,chord,aMinSOETrans,mu,TransAng,true).
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
            DisplayDiagnosticMN(vTransDvVec,tDepTStmp).
//            kuniverse:pause().
            if vTransDvVec:mag < vPreviousDv
              or vTransDvVec:mag > 10
              {
                set ThrottleSet to 1.
                if vTransDvVec:mag > 10
                  set SteeringDir to lookDirUp(vTransDvVec,ship:up:forevector).
                set vPreviousDv to vTransDvVec:mag.
              }
            else
              {
                set ThrottleSet to 0.
                set finished to true.
              }
          }
        else
          {
            MFDFunctions["DisplayError"]("Parabolic or hyperbolic orbits are not supported").
            wait until false.  // Freeze program.
          }
        wait 0. // Force at least one physics frame per loop iteration.
      }
    unlock throttle.
    unlock steering.
  }

local function DoReentryFlipManeuver
  {
// Do the flip prior to the atmospheric reentry.
// Notes:
//    - 
//    -
// Todo:
//    -
    MFDFunctions["DisplayFlightstatus"]("Reentry flip").
    lock steering to lookDirUp (ship:up:forevector,ship:north:forevector).
    rcs on.
    brakes on.
    if WarpType <> "NOWARP"
      {
        set kuniverse:timewarp:mode to WarpType.
        set kuniverse:timewarp:warp to 3.
      }
    wait until vang(ship:up:forevector,ship:facing:forevector) < 1.  
    kuniverse:timewarp:cancelwarp().
  }

local function DoLandingManeuverLambert
  {
// Do the landing maneuver to slow down and land.
// Notes:
//    - IMPORTANT! The course-correcting method used requires
//      a strong downwards velocity vector to avoid the vessel
//      flipping as it slows. Atmospheric drag is a problem
//      with a long rocket such as a super heavy booster.
//    - IMPORTANT! The course-correction method used is
//      OK but not miraculous. On the final part of the descent,
//      the vessel has to be almost vertical which depends on a
//      number of factors.
//      Try and see if MechJeb can handle it :-)
//    - The braking burn course-corrects by continuously
//      calculating a trajectory toward the landing spot.
//      Air resistance and fuel consumption during landing
//      make an efficient suicide burn a challenge.
//      Experiments have shown this code gives good results.
//    -
// Todo:
//    -

// Speed to use after the suicide burn completes.
    local MinSpeed to 50.

// Maximum angle the booster is allowed to pitch
// from the vertical.
    local MaxPitchAng to 10.

    local SuicideBurn to false.
    local HoverBurn to false.
    local LandingBurn to false.
    local r1 to 0.
    local r2 to 0.
    local chord to 0.
    local TransAng to 0.
    local ThrottleSet to 0.0.
    local tMinTransTSpan to timespan(0).
    local aMinSOETrans to 0.
    local tShortwayOrbitMaxTSpan to timespan(0).
    local finished to false.
    local vTransVec to v(0,0,0).
    local vTransDvVec to v(0,0,0).
    local r1Vec to v(0,0,0).
    local r2Vec to v(0,0,0).
    local LSVec to v(0,0,0).
    local aTrans to 0.0.
    local SteeringVec to v(0,0,0).
    local tTransTSpan to timespan(0).
    local tDepTStmp to timestamp(0).
    local ShortWayOrbit to false.
    local EndHeight to 0.0.
    local vPrevious to 99999.9.

// PID controller to regulate the speed
// by controlling the throttle.
    local SpeedPID to PIDLoop().
    set SpeedPID:kp to 0.1.
    set SpeedPID:ki to 0.1.
    set SpeedPID:kd to 0.01.
    set SpeedPID:minoutput to 0.
    set SpeedPID:maxoutput to 1.

// PID controller to regulate the acceleration
// using by controlling the throttle.
    local AccPID to PIDLoop().
    set AccPID:kp to 0.01.
    set AccPID:ki to 0.1.
    set AccPID:kd to 0.0.
    set AccPID:minoutput to 0.
    set AccPID:maxoutput to 1.

// Redefine the "height above the ground" from the COM of the ship
// to the bottom of the vessel. This was delayed until now
// so the ship configuration and bounding box are in their final
// state (ignoring any landing legs deployment).
    local BBox to ship:bounds.
    local lock HeightAGLBottom to BBox:bottomaltradar.  
    wait 0.
    if WarpType <> "NOWARP"
      {
        set kuniverse:timewarp:mode to WarpType.
        set kuniverse:timewarp:warp to 3.
      }
    until ship:altitude < ship:body:atm:height.
      {
        wait 0.
      }
    kuniverse:timewarp:cancelwarp().
    MFDFunctions["DisplayFlightstatus"]("Descent").

// Wait until atmosphere.
    wait until ship:altitude < ship:body:atm:height.

    set SteeringVec to -ship:velocity:surface.
    lock steering to lookDirUp (SteeringVec,ship:north:forevector).

// Wait until atmospheric drag becomes significant.
    until ship:body:atm:altitudepressure(ship:altitude) > DragSensibleAtmosphereLimit
      {
        set SteeringVec to -ship:velocity:surface.
        wait 0.
      }

// Wait until the vessel reaches terminal velocity.
    until ship:velocity:surface:mag < vPrevious
      {
        set vPrevious to ship:velocity:surface:mag.
        set SteeringVec to -ship:velocity:surface.
        wait 0.
      }

    set ThrottleSet to 0.
    lock throttle to ThrottleSet.
    set tDepTStmp to timestamp().
    set tTransTSpan to tArrTStmp-tDepTStmp.

    until finished
      {
//        set EndHeight to DescentHeight+LandingHeight.
        set EndHeight to 0.
        set r1Vec to ship:position-ship:body:position.
        set r2Vec to CalcGeoPositionAt(LandingGeo,EndHeight,tDepTStmp)-ship:body:position.
        set TransAng to vang(r1Vec,r2Vec).
        set r1 to r1Vec:mag.
        set r2 to r2Vec:mag.
        set chord to (r2Vec-r1Vec):mag.
        set aTrans to CalcSMALambert(tTransTSpan,r1,r2,chord,ship:body:mu,TransAng).
        set tMinTransTSpan to
          CalcParabolicTransferTimeLambert(r1,r2,chord,ship:body:mu,TransAng).
        set aMinSOETrans to (r1+r2+chord)/4.
        set tShortWayOrbitMaxTSpan to
          CalcTransferTimeLambert(r1,r2,chord,aMinSOETrans,ship:body:mu,TransAng,true).
        if tTransTSpan < tShortWayOrbitMaxTSpan
          set ShortWayOrbit to true.
        else
          set ShortWayOrbit to false.
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
        DisplayDiagnosticMN(vTransDvVec,tDepTStmp).
        MFDFunctions["DisplayDiagnostic"]
          (tMinTransTSpan+" "
          +tShortWayOrbitMaxTSpan,
          round(CalcGeoPositionAt(LandingGeo,EndHeight,tArrTStmp):mag,2)+" "
          +round(vTransVec:mag,2)+" "
          +round(vxcl(ship:velocity:orbit,vTransVec):mag,2)).
// Todo: document assumptions here.
        if not SuicideBurn
          and CalcStoppingDistance(ship:velocity:surface) > CalcGeoPositionAt(LandingGeo,EndHeight,tDepTStmp):mag
          {
            set SuicideBurn to true.
            MFDFunctions["DisplayFlightstatus"]("Suicide burn").
            rcs on.
            brakes off.
//            set AccPID:setpoint to CalcRelativeAcceleration(ship:availablethrust).
            set SteeringVec to vTransDvVec.
            set ThrottleSet to 1.
            set vPrevious to 99999.9.
          }
        if SuicideBurn
          {
            if ship:verticalspeed < -MinSpeed
              {
                set vPrevious to vTransDvVec:mag.
                set SteeringVec to
                  -ship:velocity:orbit-vxcl(ship:velocity:orbit,vTransDVVec).
              }              
            else
              {
                set SuicideBurn to false.
                set HoverBurn to true.
                MFDFunctions["DisplayFlightstatus"]("Hover burn").
                set SpeedPID:setpoint to -MinSpeed.            
              }
          }
        if HoverBurn
          {
            set SteeringVec to
              ship:up:forevector*MinSpeed+vxcl(ship:velocity:orbit,vTransDVVec).
            set ThrottleSet to SpeedPID:update(time:seconds,ship:verticalspeed).
          }
        if not LandingBurn 
          and HeightAGLBottom < LandingHeight
          {
            set LandingBurn to true.
            set HoverBurn to false.
            set SpeedPID:setpoint to -LandingSpeed.
          }
        if LandingBurn
          {
            set SteeringVec to
              ship:up:forevector*LandingSpeed-ship:velocity:surface/10.
//              vxcl(ship:up:forevector,vTransVec)+ship:up:forevector*LandingSpeed.
            set ThrottleSet to SpeedPID:update(time:seconds,ship:verticalspeed).
            if ship:status = "LANDED"
              {
                set LandingBurn to false.
                set finished to true.
              }
          }
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

// Todo: document assumptions here.
        set tTransTSpan to
          (tMinTransTSpan+tShortWayOrbitMaxTSpan)/2.
        set tDepTStmp to timestamp().
        set tArrTStmp to tDepTStmp+tTransTSpan.
        wait 0. // Force at least one physics frame per loop iteration.
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
//    - The stopping distance is an instantaneous calculation
//      based on the state of the vessel at that time.
//      In practice it gives a ballpark figure only.
//    - Fuel consumption is ignored.
//    - Air resistance is ignored.
//    - Assumption: The craft has reached terminal velocity
//      because of the airbrakes, and is no longer accelerating
//      due to gravity.
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

local function CalcRelativeAcceleration
  {
// Calculate the acceleration of a vessel
// relative to the free-falling or orbital frame?
// Notes:
//    - The point of this calculation is to
//      provide an acceleration value that can be
//      used to regulate the deacceleration of a vessel
//      towards a landing spot.
//    - Air resistance is ignored.
//    -
// Todo:
//    -
    parameter thrust to 0.0.    // Vessel thrust.

    local GravityAcc to 0.
    local GravityVec to v(0,0,0).
    local ThrustAcc to 0.
    local ThrustVec to v(0,0,0).
    local RelativeAcc to 0.0.
    local RelativeVec to 0.0.

    set GravityAcc to ship:body:mu/(ship:body:radius+ship:altitude)^2.
    set ThrustAcc to thrust/ship:mass.
    set GravityVec to -ship:up:forevector*GravityAcc.
    set ThrustVec to ship:facing:forevector*ThrustAcc.
//    set RelativeVec to ThrustVec+GravityVec.
    set RelativeVec to ThrustVec.
    if vdot(RelativeVec,ship:facing:forevector) > 0
      set RelativeAcc to RelativeVec:mag.
    else
      set RelativeAcc to -RelativeVec:mag.
    return RelativeAcc.
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
        DescentHeight,
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
    parameter WarpTypeCode to "".

    if WarpTypeCode = "NOWARP"
      wait until timestamp() > WaitToTStmp.
    else
    if WarpTypeCode = "PHYSICS"
      {
        set kuniverse:timewarp:mode to WarpTypeCode.
        kuniverse:timewarp:warpTo(WaitToTStmp:seconds).
        wait until timestamp() > WaitToTStmp.
      }
    else
    if WarpTypeCode = "RAILS"
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

// This "wait until" runs independently of the time warp.
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