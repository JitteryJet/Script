// Career1. Career Mode script.
// Used in the "Kerbal Career Using kOS" YouTube series.

@lazyglobal off.
runoncepath("Archive:/Kerbal Career Using kOS/CareerLib1").
local DiagnosticMN to 0.
local WarpType to "RAILS".  // NOWARP,PHYSICS,RAILS.

set ship:control:pilotmainthrottle to 0.
SAS off.
RCS off.
brakes off.
lights off. // Required to stop kOS module lights draining batteries.

unlock throttle.

wait 10. DockISSModules
    (vessel("ISS 01 A"),
    vessel("ISS 01"),
    10).
//wait 15. DoISSModuleRendezvous(vessel("ISS 01 A")).

local function DockISSModules
  {
// Dock two ISS modules together, the "dockee" and "docker".
// Assumptions:
//    - The modules have to start together (ie 50 metres).

    parameter DockeeShip.
    parameter DockerShip.
    parameter SteerSecs.

    lock RelVel to ship:velocity:orbit-DockeeShip:velocity:orbit.
    lock ClosingSpeed to
      vdot(RelVel,DockeeShip:position)/DockeeShip:position:mag.
    local ForeSpeedPID to pidloop().
    local docked to false.

    set ForeSpeedPID:kp to 1.
    set ForeSpeedPID:ki to 0.
    set ForeSpeedPID:kd to 0.
    set ForeSpeedPID:minoutput to -1.
    set ForeSpeedPID:maxoutput to 1.

// Target for diagnostic purposes.
    set target to DockeeShip.

    lock steering to DockeeShip:facing.
    wait SteerSecs.

    set ForeSpeedPID:setpoint to 1.
    rcs on.
    until docked
      {
        set ship:control:fore to
          ForeSpeedPID:update(timestamp():seconds,
          ClosingSpeed).
        print round(ClosingSpeed,2)+" "+round(ship:control:fore,2).
        wait 1.
      }
  }

local function DoISSModuleRendezvous
  {
// Rendezvous a space station module with another
// space station module.

    parameter MyTarget.

    clearscreen.
    print "Running ISS Rendezvous program".
    DoLaunchToOrbit
      (100000,
       0.5,
       10,
       5,
       0.72,
       0.50,
       10).
// The Mun can be used as a zero-inclination reference until I code an
// inclination change function.
    DoPlaneChangeTarget(body("Mun")).
    print "Chase orbit in progress".
    wait 1. // Workaround for phantom acceleration warping bug.
    DoWarpSpeed(WarpType,4).
    wait until MyTarget:position:mag <= 25000.
    StopWarpSpeed().
    DoISSCloseApproach(MyTarget).
// Extra wait - workaround for a weird bug where the stage does not shut off
// it's engines before staging.
    wait 1.
    stage.
  }

local function DoISSCloseApproach
  {
// Do a close approach of a space station module with
// another space station module.
// Assumptions:
//    - The modules start out in almost in the same orbit
//      and are close (eg less than 10km).
// Notes:
//    - Position calculation might be a little off
//      because the vessel's position is take from the
//      centre of mass (COM).

    parameter MyTarget.

    local MaxApproachSpeed to 50.0.
    local MinApproachSpeed to 0.5.
    local SafeDistance to 2000. // Make large enough to slow approach gradually.
    local MaxThrustSecs to 5.
    local SteeringSecs to 10.
    local CloseApproachDistance to 50.
    local MaxCloseApproachSpeed to 5.
    local ThrottleSet to 0.0.
    local CloseApproach to false.
// Relative Velocity to/from target same as on Nav Ball.
    lock RelVel to ship:velocity:orbit-MyTarget:velocity:orbit.
// Closing speed is negative if moving away.
    lock ClosingSpeed to
      vdot(RelVel,MyTarget:position)/MyTarget:position:mag.
    lock ApproachSpeed to
      min(((MyTarget:position:mag)/SafeDistance)*MaxApproachSpeed,MaxApproachSpeed).
    lock ApproachVel to ApproachSpeed*MyTarget:position:normalized.
    lock ThrustSecs to
      min((MyTarget:position:mag/SafeDistance)*MaxThrustSecs,MaxThrustSecs).
    lock throttle to ThrottleSet.
    print "Running Close Approach program".
    until CloseApproach
      {
        print "Separation: "+round(MyTarget:position:mag/1000,3)+" km "
          +"Safe Approach spd: "+round(ApproachSpeed,1)+" m/s "
          +"Closing spd: "+round(ClosingSpeed,1)+" m/s". 
        if MyTarget:position:mag < CloseApproachDistance
          and RelVel:mag < MaxCloseApproachSpeed
          {
            print "Close Approach maneuver".
            print "Kill relative velocity".
            lock steering to -RelVel.
            wait SteeringSecs.
            set ThrottleSet to 0.01.
            wait until RelVel:mag < 0.1.
            set CloseApproach to true.
          }
        else
        if ClosingSpeed < ApproachSpeed*0.9
          and abs(ClosingSpeed) > MinApproachSpeed
          {
            print "Increasing speed towards target".
            lock steering to ApproachVel-RelVel.
            wait SteeringSecs.
            set ThrottleSet to 0.1.
            wait until ClosingSpeed > ApproachSpeed.
          }
        else
        if ClosingSpeed > ApproachSpeed*1.1
          and abs(ClosingSpeed) > MinApproachSpeed
          {
            print "Decreasing speed towards target".
            lock steering to ApproachVel-RelVel.
            wait SteeringSecs.
            set ThrottleSet to 0.1.
            wait until ClosingSpeed < ApproachSpeed.
          }
        else
          {
            print "Coasting to conserve resources".
            set ThrottleSet to 0.0. wait 0. // Switch off engines before steering.
            lock steering to "kill".
            wait ThrustSecs.
          }
        set ThrottleSet to 0.0.
        wait 0.  // Wait for next physics tick.
      }
  }

local function DoLaunchISSModule
  {
// Launch a ISS Module into orbit.

    clearscreen.
    print "Running Launch ISS Module program".
    DoLaunchToOrbit
      (120000,
       0.5,
       10,
       5,
       0.75,
       0.50,
       10).
// The Mun can be used as a zero-inclination reference until I code an
// inclination change function.
    DoPlaneChangeTarget(body("Mun")).
// Extra wait - workaround for a weird bug where the stage does not shut off
// it's engines before staging.
    wait 1.
    stage.
  }

local function DoLandOnMun
  {
// Land on the Mun and return to Kerbin.

    local TargetMoon to body("Mun").

    clearscreen.
    print "Running Land on Mun program".
    DoLaunchToOrbit
      (100000,
       3.5,
       10,
       10,
       0.80,
       1.0,
       10).
    DoPlaneChangeTarget(TargetMoon).
// Extra wait - workaround for a weird bug where the stage does not shut off
// it's engines before staging.
    wait 1.
    stage. // Stage to remove unwanted engine and tank.
    until stage:ready {wait 0.} // Just in case.
    stage. // Stage to activate engines in next stage.
    DoTransferToMoon(TargetMoon).
    DoFlybyOfMoon(10000,"PROGRADE").
    DoOrbitMoonFromFlyby().
    DoMunDescent().
    DoLaunchToOrbit
      (10000,
       0.0,
       80,
       1,
       0.25,
       0.25,
       5).
    DoReturnFromMoon().
    DoMoonParentReturn().
  }

local function DoMunDescent
  {
// Mun Descent and landing.

    local finished to false.
    local SteeringSecs to 10.0.
    local SteeringDir to r(0,0,0).
    local MinSpeed to 9999999.9.
    local DescentSpeed to pidloop().

    set DescentSpeed:kp to 1.0.
    set DescentSpeed:ki to 0.0.
    set DescentSpeed:kd to 1.0.
    set DescentSpeed:minoutput to -1.0.
    set DescentSpeed:maxoutput to 0.0.
    set DescentSpeed:epsilon to 0.0.

    print "Running Mun Descent program".
    set SteeringDir to lookdirup(-ship:velocity:orbit,ship:facing:topvector).
    lock steering to SteeringDir.
    wait SteeringSecs.
    lock throttle to 1.
    wait 0.2.
    until finished
      {
        if ship:velocity:orbit:mag <= MinSpeed
          set MinSpeed to ship:velocity:orbit:mag.
        else
          set finished to true.
        wait 0.
      }
    lock throttle to 0.
    lock steering to lookdirup(-ship:velocity:surface,ship:facing:topvector).
    wait SteeringSecs.
    set DescentSpeed:setpoint to 150.
    lock throttle to
      -DescentSpeed:update(timestamp():seconds,ship:velocity:surface:mag).
    wait until alt:radar<400.
    set DescentSpeed:setpoint to 5.
    gear on.
    wait until ship:status="LANDED".
    lock throttle to 0.
    lock steering to lookdirup(ship:up:forevector,ship:facing:topvector).
    print "The ship has landed".
    wait 10.
    unlock steering.
    unlock throttle.
    DoVesselScienceExperiments().
    GoEVA().
    wait 15.
  }

local function DropKerbalAtMinmus
  {
// Drop a kerbal at Minmus and pick them up later.
    local TargetMoon to body("Minmus").
//    local TargetShip to vessel("Burcas' Wreckage").

    clearscreen.
    print "Running Drop Kerbal at Minmus program".
    DoLaunchToOrbit
      (100000,
       8,
       10,
       6,
       0.73,
       0.45,
       10).
    DoPlaneChangeTarget(TargetMoon).
    DoTransferToMoon(TargetMoon).
    DoFlybyOfMoon(10000,"PROGRADE").
//    DoSpaceScienceExperiments().
    DoOrbitMoonFromFlyby().
//    DoSpaceScienceExperiments().
//    DoEVAFromParkingOrbit().
//    DoReturnFromMoon().
//    DoMoonParentReturn().
  }

local function DoRecoverAtMinmus
  {
// Do recover contracts around Minmus.
    local TargetMoon to body("Minmus").
    local TargetShip to vessel("Burcas' Wreckage").

    clearscreen.
    print "Running Recover at Minmus program".
    DoLaunchToOrbit
      (100000,
       8,
       10,
       6,
       0.73,
       0.45,
       10).

    DoPlaneChangeTarget(TargetMoon).
    DoTransferToMoon(TargetMoon).
    DoFlybyOfMoon(130000,"PROGRADE").
    DoSpaceScienceExperiments().
    DoOrbitMoonFromFlyby().
    DoPlaneChangeTarget(TargetShip).
    DoSpaceScienceExperiments().
    DoRecoverPart(TargetShip).
    DoReturnFromMoon().
    DoMoonParentReturn().
  }

local function DoTransferToMoon
  {
// Transfer from a parking orbit to the specified moon.

    parameter moon.

    local SearchList to list().
    local TransferDv to 0.0.
    local ManeuverpointTStmp to timestamp().
    local BurnTotalSecs to 0.0.
    local BurnSplit1Secs to 0.0.
    local BurnStartTStmp to timestamp().
    local BurnVec to v(0,0,0).
    local SteeringSecs to 10.
    local ThrottleSet to 0.0.
    local ThrustDelaySecs to 0.06. // 3x1/50 sec physics ticks.

    print "Running Transfer To Moon program".
    set SearchList to SearchForTransferOrbit(moon).
    if SearchList:length=0
      print 0/0. // No transfer orbit found.
    else
      {
        print "Transfer to "+Moon:name.
        set TransferDv to SearchList[0].
        set ManeuverpointTStmp to Searchlist[1].
        set BurnTotalSecs to CalcBurnTimeFromDeltaV(TransferDv).
        set BurnSplit1Secs to CalcBurnTimeFromDeltaV(TransferDv/2).
        set BurnStartTStmp to
          ManeuverpointTStmp-BurnSplit1Secs-ThrustDelaySecs.
        print round(TransferDV,1)+" "+round(BurnTotalSecs,1)
          +" "+round(BurnSplit1Secs,1).
        wait 1. // Workaround for phantom acceleration warping bug.
        DoSafeWait(BurnStartTStmp-SteeringSecs,WarpType).
        
// Calculate the steering vector AFTER timewarping and waiting.
        set BurnVec to velocityat(ship,ManeuverpointTStmp):orbit.
        lock steering to lookdirup(BurnVec,ship:facing:topvector).
        lock throttle to ThrottleSet.
        wait SteeringSecs.
        set ThrottleSet to 1.
        wait BurnTotalSecs+ThrustDelaySecs.
        set ThrottleSet to 0.
// Trim the transfer orbit.
        if ship:orbit:apoapsis < moon:orbit:apoapsis
          {
            print "Trimming transfer orbit".
            lock steering to lookdirup(ship:velocity:orbit,ship:facing:topvector).
            wait SteeringSecs.
            until ship:orbit:apoapsis > moon:orbit:apoapsis
              {
                set ThrottleSet to
                  min((moon:orbit:apoapsis-ship:orbit:apoapsis)/10E3+0.01,0.1).
                wait 0.
              }
            set ThrottleSet to 0.
          }
        unlock steering.
        unlock throttle.
      }
  }

local function DoEVAFromParkingOrbit
  {
// EVA kerbal from a parking orbit.
// Notes:
//    - The kerbal is EVAed from the UP direction to avoid hitting
//      the ship when the kerbal's jetpack is toggled. This is because
//      an animation is run and the kerbal orients to UP automatically.
//    - This program will disappear if the ship is
//      no longer the active vessel (the kerbal becomes the active vessel)
//      and it moves out of packed distance - this is the way KSP works.

    local SteeringSecs to 10.0.
    local BootfileName to "MotherShipBootfile".

    // Copy the boot file to the local drive of the kOS processor.
    // This script will be ran when the Mother Ship is made active by the
    // kerbal.
    copypath("Archive:/Kerbal Career Using kOS/MotherShipBootfile"
      ,BootfileName).
    set core:bootfilename to BootfileName.

    lock steering to lookdirup(ship:velocity:orbit,ship:up:forevector).
    wait SteeringSecs.
    GoEVA().
    wait 5. // Give the kerbal enough time to get clear.
    lock steering to lookdirup(ship:velocity:orbit,-ship:up:forevector).
    wait SteeringSecs.
    unlock steering.
    unlock throttle.
  }

local function DoFlybyOrbitReturn
  {
// Do a flyby,orbit,return for a moon.

    parameter MoonName.

    clearscreen.
    print "Running Flyby/Orbit/Free-return program".
    DoFlybyMission(MoonName).
    DoSpaceScienceExperiments().
    DoOrbitMoonFromFlyby().
    DoSpaceScienceExperiments().
//    wait 30.
//    DoReturnFromMoon().
//    DoMoonParentReturn().
  }

local function DoReturnFromMoon
  {
// Escape from a moon and return to the parent body.
// Assumptions:
//    - I think a hidden assumption is the ship is more-or-less in a
//      circular equatorial orbit for best results.
// Note:
//    - The Ejection point for the escape burn is set to
//      the leading point in the moon's orbit.
//      This SHOULD give an efficient escape but I do not
//      know for certain. 

    local ShipPosVec to v(0,0,0).
    local ShipVelVec to v(0,0,0).
    local ShipTrueAnomalyAng to 0.0.

    wait 0. // Wait for next physics tick to get up-to-date values.

// Copy Orbital State Vectors to temporary variables so the values
// do not change during code execution.
    set ShipPosVec to ship:position-ship:body:position.
    set ShipVelVec to ship:velocity:orbit.
    set ShipTrueAnomalyAng to ship:orbit:trueanomaly.

// Calculate the normal vector for each orbit.
// Cross product parameter order is important! Left-hand rule.
    local ShipNormalVec to vcrs(ShipPosVec,ShipVelVec).

    local EccentricityVec to v(0,0,0).
    local EjectionTrueAnomalyAng to 0.0.
    local EjectionETASecs to 0.0.
    local ManeuverpointTStmp to timestamp(0).
    local BurnStartTStmp to timestamp(0).
    local radius to 0.0.
    local EscapeSpeed to 0.0.
    local OldSpeed to 0.0.
    local BurnTotalSecs to 0.0.
    local BurnSplit1Secs to 0.0.
    local BurnVec to v(0,0,0).
    local DeltaV to 0.0.
    local SteeringSecs to 10.0.

    set EccentricityVec to
      CalcEccentricityVec
        (ShipPosVec,
         ShipVelVec,
         ship:body:mu).

    set EjectionTrueAnomalyAng to
      CalcTrueAnomalyFromVec
        (ship:body:orbit:velocity:orbit,
         EccentricityVec,
         ShipNormalVec).

    set EjectionETASecs to
      CalcOrbitPositionETA
          (ShipTrueAnomalyAng,
           EjectionTrueAnomalyAng,
           ship:orbit:eccentricity,
           ship:orbit:period).

    set ManeuverpointTStmp to timestamp()+EjectionETASecs.

    print "Running Return From Moon program".
    print "Ejection ETA "+round(EjectionETASecs,1)+" seconds".
    set radius to (positionat(ship,ManeuverpointTStmp)-ship:body:position):mag.
    set EscapeSpeed to sqrt(2*ship:body:mu/radius).
    set OldSpeed to velocityat(ship,ManeuverpointTStmp):orbit:mag.
    set DeltaV to EscapeSpeed-OldSpeed.
    set BurnTotalSecs to CalcBurnTimeFromDeltaV(DeltaV).
    set BurnSplit1Secs to CalcBurnTimeFromDeltaV(DeltaV/2).
    print round(DeltaV,1)+" "+round(BurnTotalSecs,1)
      +" "+round(BurnSplit1Secs,1).
    set BurnStartTStmp to ManeuverpointTStmp-BurnSplit1Secs.
    wait 1. // Workaround for phantom acceleration warping bug.
    DoSafeWait(BurnStartTStmp-SteeringSecs,WarpType).
// Recalculate the steering vector after a wait. The velocity vector origin may have
// shifted?
    set BurnVec to velocityat(ship,ManeuverpointTStmp):orbit.
    lock steering to lookdirup(BurnVec,ship:facing:topvector).
    wait SteeringSecs.
    lock throttle to 1.
    wait BurnTotalSecs.
    lock throttle to 0.
    print "Ejection completed".
    unlock steering.
  }

local function DoOrbitMoonFromFlyby
  {
// Do orbit the moon from a flyby trajectory.
// Notes:
//    -
// Todo:
//    - Check the circularization. It sometimes gives poor results.

    local CaptureDeltaV to 0.0.
    local BurnTotalSecs to 0.0.
    local BurnSplit1Secs to 0.0.
    local ManeuverpointTStmp to timestamp(0).
    local BurnStartTStmp to timestamp(0).
    local SteeringSecs to 10.0.
    local BurnVec to v(0,0,0).
    local NewSpeed to 0.0.
    local OldSpeed to 0.0.

    print "Running capture maneuver program".
    set ManeuverpointTStmp to timestamp()+eta:periapsis.
    set OldSpeed to velocityat(ship,ManeuverpointTStmp):orbit:mag.
    set NewSpeed to sqrt(ship:body:mu*(1/(ship:body:radius+ship:obt:periapsis))).
    set CaptureDeltaV to abs(NewSpeed-OldSpeed).
    set BurnTotalSecs to CalcBurnTimeFromDeltaV(CaptureDeltaV).
    set BurnSplit1Secs to CalcBurnTimeFromDeltaV(CaptureDeltaV/2).
    print round(CaptureDeltaV,1)+" "+round(BurnTotalSecs,1)
      +" "+round(BurnSplit1Secs,1).
    set BurnStartTStmp to ManeuverpointTStmp-BurnSplit1Secs.
    wait 1. // Workaround for phantom acceleration warping bug.
    DoSafeWait(BurnStartTStmp-SteeringSecs,WarpType).
// Calculate a fresh vector in case KSP has floated the vector origins.
    set BurnVec to -velocityat(ship,ManeuverpointTStmp):orbit.
    lock steering to lookdirup(BurnVec,ship:facing:topvector).
    wait SteeringSecs.
    lock throttle to 1.0.
    wait BurnTotalSecs.
    lock throttle to 0.0.
    print "Ship captured".
    unlock steering.
  }

local function DoSpaceScienceExperiments
  {
// Do the science experiments from space.

    print "Running Scientific Experiments in spaaaacccceee program".
    DoVesselScienceExperiments().
    wait 5.
    GoEVA().
// Wait long enough for the Kerbal to reboard the vessel otherwise bad things
// might happen.
    wait 15.
  }

local function DoMoonParentReturn
  {
// Return to the parent body of a moon.

    local EntryPeriapsisAlt to 40000.
    local EntryStageSeparationLeadSecs to 180. // Time before Atm Entry periapsis.

    local ParentBodyName to ship:body:name.

    print "Running Moon Parent Return program".
    wait 1. // Workaround for phantom acceleration warping bug.
    DoSafeWait(timestamp()+eta:transition,WarpType).
// Exit Moon SOI.
    wait until ship:body:name<>ParentBodyname.
    print "Entered SOI: "+ship:body:name.
    wait 5.
    DoPeAdjustment(EntryPeriapsisAlt,10).
    unlock steering.
    wait 1. // Workaround for phantom acceleration warping bug.
    DoSafeWait(timestamp()+eta:periapsis-EntryStageSeparationLeadSecs,WarpType).
    print "Stage separation for Atmospheric Entry".
    lock steering to -ship:velocity:surface.
    wait 10.
    until stage:number = 0
      {
        stage.
        wait until stage:ready.
      }
    print "Parachutes armed".
    chutes on.
    wait until (ship:status="LANDED" or ship:status="SPLASHED").
    unlock steering.
  }

local function DoRecoverPart
  {
// Do the Recover/Rescue contracts.

    parameter MyTarget.

    local DockingDistance to 15000.

    print "Run Recover Part program".
    print "Target name: "+MyTarget:name.
    print "Wait for a close approach".
//    set mapView to true.
    DoWarpSpeed(WarpType,4).
    until MyTarget:position:mag < DockingDistance
      {
//        set mapview to true.
//        wait 10.
//        set mapview to false.
//        wait 60.
        wait 0.
      }
    StopWarpSpeed().
//    set mapView to false.
    DoRendezvous(MyTarget).
  }

local function DoFlybyMission
  {
// Do a Flyby Mission.
// Assumptions:
//    - 
// Notes:
//    -

    parameter MoonName.

    local MyBody to body(MoonName).
    local BurnTotalSecs to 0.0.
    local BurnSplit1Secs to 0.0.
    local BurnStartTStmp to timestamp(0).
    local ThrustDelaySecs to 0.06. // Usually 3 physics ticks (1/50 secs)
    local SearchList to list().
    local ManeuverpointTStmp to timestamp(0).
    local TransferDeltav to 0.0.
    local ShipOrbitVelVecAt to v(0,0,0).
    local SteeringSecs to 10.0.
    local ThrottleSet to 0.0.

    print "Running Flyby Moon program".
    DoLaunchToOrbit
      (100000,
       5,
       10,
       5,
       0.70,
       0.45,
       10).
    DoPlaneChangeTarget(MyBody).
    set SearchList to SearchForTransferOrbit(MyBody).
    if SearchList:length <> 0
      {
        print "Transfer to "+MyBody:name.
        set TransferDeltav to SearchList[0].
        set ManeuverpointTStmp to Searchlist[1].
        set BurnTotalSecs to CalcBurnTimeFromDeltaV(TransferDeltaV).
        set BurnSplit1Secs to CalcBurnTimeFromDeltaV(TransferDeltaV/2).
        set BurnStartTStmp to
          ManeuverpointTStmp-BurnSplit1Secs-ThrustDelaySecs.
        print round(TransferDeltaV,1)+" "+round(BurnTotalSecs,1)
          +" "+round(BurnSplit1Secs,1).
        wait 1. // Workaround for phantom acceleration warping bug.
        DoSafeWait(BurnStartTStmp-SteeringSecs,WarpType).
// Calculate the steering vector AFTER timewarping and waiting.
        set ShipOrbitVelVecAt to
          velocityat(ship,ManeuverpointTStmp):orbit.
        lock steering to lookdirup(ShipOrbitVelVecAt,ship:facing:topvector).
        wait SteeringSecs.
        lock throttle to 1.
        wait BurnTotalSecs.
        lock throttle to 0.
// Trim the transfer orbit.
        if ship:orbit:apoapsis < MyBody:orbit:apoapsis
          {
            print "Trimming transfer orbit".
            lock steering to lookdirup(Ship:velocity:orbit,ship:facing:topvector).
            lock throttle to ThrottleSet.
            wait SteeringSecs.
            until ship:orbit:apoapsis > MyBody:orbit:apoapsis
              {
                set ThrottleSet to
                  min((MyBody:orbit:apoapsis-Ship:orbit:apoapsis)/10E3+0.01,0.1).
                wait 0.
              }
            set ThrottleSet to 0.
          }
        unlock steering.
        unlock throttle.
        DoFlybyManeuver(10000,"PROGRADE").
      }
  }

local function DoFlybyOfMoon
  {
// Do a flyby of a moon.
// Assumptions:
//    - The ship is already on a transfer orbit to the moon.

    parameter FlybyAlt.
    parameter OrbitType.

    local ParentBodyName to ship:body:name.

    print "Running Flyby Of A Moon program".
    wait 1. // Workaround for phantom acceleration warping bug.
    DoSafeWait(timestamp()+eta:transition,WarpType).
// Enter Moon SOI.
    wait until ship:body:name<>ParentBodyname.
    print "Entered SOI: "+ship:body:name.
    DoPeAdjustmentRadial(FlybyAlt,OrbitType,10).
  }

local function SearchForTransferOrbit
  {
// Search for an elliptical transfer orbit to a target body.
// Assumption:
//    - The vessel and orbital are in the same orbital plane
//      ie have a relative inclination of around zero.
//    - The target orbit is circular (or close to circular).
// Notes:
//    - The distance between the candidate transfer orbit and
//      the orbital is only checked at the apoapsis of the
//      transfer orbit. This means other close approaches might
//      be missed.
// Todo:
//    - Consider replacing the "first found" transfer orbit
//      with the "best found" transfer orbit.

    parameter TargetBody.

    local TransferDeltav to 0.0.
    local TransferOrbitVelVec to v(0,0,0).
    local TargetOrbitRadius to 0.0.
    local ShipOrbitRadius to 0.0.
    local ManeuverpointTStmp to timestamp(0).
    local SearchEndTStmp to timestamp(0).
    local ShipOrbitVelVecAt to v(0,0,0).
    local SearchEnd to false.
    local TransferFound to false.
    local CandidateTransfer to 0.
    local ShipPositionAt to v(0,0,0).
    local TargetPositionAt to v(0,0,0).
    local ReturnList to list().
    local ApseAngle to 0.0.
// Apse angle tolerance is a balance. Too large and it returns a poor match.
// Too small and a match may not be found.
    local ApseAngleTolerance to 1.5.
    local SearchStepSecs to 10.0.

    set ManeuverpointTStmp to timestamp()+ship:orbit:period/2.
    set SearchEndTStmp to ManeuverpointTStmp+ship:orbit:period.

    print "Search for transfer orbit".

    until SearchEnd or TransferFound
      {
        set ShipPositionAt to
          positionat(ship,ManeuverpointTStmp)-ship:body:position.
        set TargetPositionAt to
          positionat(TargetBody,ManeuverpointTStmp)-ship:body:position.
        set ShipOrbitRadius to ShipPositionAt:mag.
        set TargetOrbitRadius to TargetPositionAt:mag. 
        set ShipOrbitVelVecAt to velocityat(ship,ManeuverpointTStmp):orbit.
        set TransferDeltav to
            CalcEllipticalTransferOrbitDeltaV
              (TargetOrbitRadius,
               ShipOrbitRadius,
               ShipOrbitVelVecAt:mag,
               ship:body:mu).
        set TransferOrbitVelVec to
          (ShipOrbitVelVecAt:mag+TransferDeltav)*ShipOrbitVelVecAt:normalized.
//        print ManeuverPointTStmp:full+" "+round(TransferDeltav,1)+" m/s".
//        DisplayDiagnosticMN(TransferDeltavVec,ManeuverPointTStmp).
        set CandidateTransfer to
          createorbit
            (ShipPositionAt,
             TransferOrbitVelVec,
             ship:body,
             ManeuverpointTStmp:seconds).
        set ApseAngle to
          vang
            (positionat
              (TargetBody,
               ManeuverpointTStmp+CandidateTransfer:eta:apoapsis)-ship:body:position,
             -ShipPositionAt).
        if ApseAngle < ApseAngleTolerance  
          {
            set TransferFound to true.
          }
        else
          {
            set ManeuverpointTStmp to ManeuverpointTStmp+SearchStepSecs.
            if ManeuverpointTStmp > SearchEndTStmp
              set SearchEnd to true.
          }
        wait 0. // Wait for next physics tick.
      }
    if TransferFound
      {
        print "Angle of target center from apse line: "+round(ApseAngle,2)+" degrees".
        ReturnList:add(TransferDeltav).
        ReturnList:add(ManeuverpointTStmp).
      }
    return ReturnList.
  }

local function DoPlaneChangeTarget
  {
// Do a plane change maneuver relative to the target orbital.
// Notes:
//    - Only the Ascending Node is calculated.
//    - The code is arranged to get orbital state values from the same
//      physics tick if possible. The values are copied to temporary
//      variables so the values will not be updated by the physics
//      engine during calculations.
// Todo:
//    - Test the code using ships in eccentric orbits.
//    - Investigate why the plane change is sometimes inaccurate by
//      up to a degree. I suspect the RAILs warping...

    parameter orbital.

    local OrbitalPosVec to v(0,0,0).
    local ShipPosVec to v(0,0,0).
    local OrbitalVelVec to v(0,0,0).
    local ShipVelVec to v(0,0,0).
    local ShipTrueAnomalyAng to 0.0.
    local CurrentTStmp to timestamp().

    wait 0. // Wait for next physics tick to get up-to-date values.

// Copy Orbital State Vectors to temporary variables so the values
// do not change during code execution.
    set OrbitalPosVec to orbital:position-ship:body:position.
    set ShipPosVec to ship:position-ship:body:position.
    set OrbitalVelVec to orbital:velocity:orbit.
// IMPORTANT! Use ship:velocity:orbit not ship:orbit:velocity:orbit
// They are not exactly the same. 
    set ShipVelVec to ship:velocity:orbit.
    set ShipTrueAnomalyAng to ship:orbit:trueanomaly.
    set CurrentTStmp to timestamp().

// Calculate the normal vector for each orbit.
// Cross product parameter order is important! Left-hand rule.
    local OrbitalNormalVec to vcrs(OrbitalPosVec,OrbitalVelVec).
    local ShipNormalVec to vcrs(ShipPosVec,ShipVelVec).

// Calculate the position vector for the Ascending Node (AN).
// Cross product parameter order is important! Left-hand rule.
    local ANPosVec to vcrs(ShipNormalVec,OrbitalNormalVec).

    local ANTrueAnomalyAng to 0.0.
    local EccentricityVec to v(0,0,0).
    local ANETASecs to 0.0.
    local PlaneChangeDeltaVVec to v(0,0,0).
    local BurnTotalSecs to 0.0.
    local BurnSplit1Secs to 0.0.
    local ManeuverPointTStmp to timestamp(0).
    local BurnStartTStmp to timestamp(0).
    local RelativeInclinationAng to vang(ShipNormalVec,OrbitalNormalVec).
    local SteeringSecs to 40.0.

    set EccentricityVec to
      CalcEccentricityVec
        (ShipPosVec,
         ShipVelVec,
         ship:body:mu).

    set ANTrueAnomalyAng to
      CalcTrueAnomalyFromVec
        (ANPosVec,
         EccentricityVec,
         ShipNormalVec).

    set ANETASecs to
      CalcOrbitPositionETA
          (ShipTrueAnomalyAng,
           ANTrueAnomalyAng,
           ship:orbit:eccentricity,
           ship:orbit:period).

    set ManeuverpointTStmp to CurrentTStmp+ANETASecs.

    print "Running Orbit Plane Change program".
    print "Target Orbital: "+orbital:name.
    print "Relative Inclination: "+round(RelativeInclinationAng,1)+" degrees".
    print "Ascending Node ETA: "+round(ANETASecs,1)+" seconds".
    set PlaneChangeDeltaVVec to
      CalcPlaneChangeDeltaVVec
        (RelativeInclinationAng,
         velocityAt(ship,ManeuverPointTStmp):orbit,
         positionAt(ship,ManeuverPointTStmp)-ship:body:position).
    set BurnTotalSecs to CalcBurnTimeFromDeltaV(PlaneChangeDeltaVVec:mag).
    set BurnSplit1Secs to CalcBurnTimeFromDeltaV(PlaneChangeDeltaVVec:mag/2).
    print round(PlaneChangeDeltaVVec:mag,1)+" "+round(BurnTotalSecs,1)
      +" "+round(BurnSplit1Secs,1).
    set BurnStartTStmp to ManeuverpointTStmp-BurnSplit1Secs.
    wait 1. // Workaround for phantom acceleration warping bug.
    DoSafeWait(BurnStartTStmp-SteeringSecs,WarpType).
//    until timestamp()>BurnStartTStmp-SteeringSecs{wait 0.}
// Recalculate the steering vector again in case the origin has shifted.
    set PlaneChangeDeltaVVec to
      CalcPlaneChangeDeltaVVec
        (RelativeInclinationAng,
         velocityAt(ship,ManeuverPointTStmp):orbit,
         positionAt(ship,ManeuverPointTStmp)-ship:body:position).
    lock steering to lookdirup(PlaneChangeDeltaVVec,ship:facing:topvector).
// Trying to work out an ETA to ascending node timing problem.
    until timestamp()>BurnStartTStmp{wait 0.}
    lock throttle to 1.
    wait BurnTotalSecs.
    lock throttle to 0.
    print "Orbit plane changed".
    unlock steering.
    unlock throttle.
  }

local function DoDeorbit
  {
// Deorbit a vessel.
// Assumptions:
//    - The parachutes and heatshield are on stage 0.

    print "Running Deorbit program".
    lock steering to lookdirup(-ship:velocity:orbit,ship:facing:topvector).
    wait 10.
    lock throttle to 1.0.
    wait until stage:number = 0.
    lock steering to lookdirup(-ship:velocity:surface,ship:facing:topvector).
    chutes on.
    lock throttle to 0.0.
    wait until (ship:status="LANDED" or ship:status="SPLASHED").
    unlock steering.
  }

local function DoLaunchToOrbit
  {
// Launch a rocket into a circular orbit.
// Notes:
//    - The best results are obtained by minimizing the
//      time used by the circularization maneuver ie
//      the flatter the gravity turn, the better. 
// Assumptions:
//    - The rocket has enough TWR and DeltaV to reach the specified
//      orbital altitude and enough time to steer and circularize
//      the orbit.
//    - The circularization burn must not stage the rocket. If it does
//      the results will be unpredictable. 

    parameter OrbitAlt.
    parameter PitchoverStartSecs to 2.
    parameter PitchoverAng to 10.
    parameter PitchoverSecs to 6.
    parameter EndoAtmThrottle to 0.67.
    parameter ExoAtmThrottle to 0.60.
    parameter SteeringSecs to 10.  // Estimated time to steer vessel.

    local DragSensibleAlt to 30000. // Alt where most drag effects end.
    local CircularizationThrottle to 1.0. // Usually always 1.0
    local ThrustDelaySecs to 0.06. // Usually 3 physics ticks (3/50 secs)
    local CircularizationDeltaV to 0.0.
    local BurnVec to v(0,0,0).
    local ManeuverpointTStmp to timestamp(0).
    local BurnStartTStmp to timestamp(0).
    local BurnSplit1Secs to 0.0.
    local BurnTotalSecs to 0.0.
    local DragSensibleAltReached to false.
    local OldSpeed to 0.0.
    local NewSpeed to 0.0.
    local ThrottleSet to 0.0.

    print "Running Launch to Orbit program".
    print "Launch".
    lock steering to heading(0,90,90).
    lock throttle to ThrottleSet.
    set ThrottleSet to 1.
    if ship:status="PRELAUNCH"
      stage.
    CreateStagingTrigger().
    wait PitchoverStartSecs.
    print "Pitchover".
    lock steering to heading(90,90-PitchoverAng,0).
    wait PitchoverSecs.
    print "Throttle-back".
    set ThrottleSet to EndoAtmThrottle.
    print "Zero-lift gravity turn".
    lock steering to lookdirup(ship:velocity:surface,ship:facing:topvector).
    until ship:orbit:apoapsis > OrbitAlt
      {
        if ship:altitude > DragSensibleAlt
          and not DragSensibleAltReached
            {
              print "Above drag-sensible atmosphere".
              set DragSensibleAltReached to true.
              lock steering to lookdirup(ship:velocity:orbit,ship:facing:topvector).
              set ThrottleSet to ExoAtmThrottle.
            }
        wait 0. // Wait for next physics tick.
      }
    set ThrottleSet to 0.0.
// Maintain Orbit altitude. It might drop due to drag.
    until ship:altitude > ship:body:atm:height
      {
        set ThrottleSet to 0.0.
        if ship:orbit:apoapsis < (OrbitAlt-10)
          {
            set ThrottleSet to 0.01.  // 1% thrust.
          }
        wait 0. // Wait for next physics tick.
      }
    set ThrottleSet to 0.0.
// Do not do the circularization calculations and maneuver steering
// until the ship is above the atmosphere!
    print "Orbit circularization".
    set ManeuverpointTStmp to timestamp()+eta:apoapsis.
    set OldSpeed to velocityat(ship,ManeuverpointTStmp):orbit:mag.
    set NewSpeed to sqrt(ship:body:mu*(1/(ship:body:radius+ship:obt:apoapsis))).
    set CircularizationDeltaV to NewSpeed-OldSpeed.
    set BurnTotalSecs to CalcBurnTimeFromDeltaV(CircularizationDeltaV).
    set BurnSplit1Secs to CalcBurnTimeFromDeltaV(CircularizationDeltaV/2).
    print round(CircularizationDeltaV,1)+" "+round(BurnTotalSecs,1)
      +" "+round(BurnSplit1Secs,1).
    set BurnStartTStmp to
      ManeuverpointTStmp-BurnSplit1Secs-ThrustDelaySecs.
    if WarpType="NOWARP"
      DoSafeWait(BurnStartTStmp-SteeringSecs,"NOWARP").
    else
      DoSafeWait(BurnStartTStmp-SteeringSecs,"PHYSICS").
    set BurnVec to velocityat(ship,ManeuverpointTStmp):orbit.
    lock steering to lookdirup(BurnVec,ship:facing:topvector).
    wait SteeringSecs.
    set ThrottleSet to CircularizationThrottle.
    wait BurnTotalSecs.
    set ThrottleSet to 0.0.
    print "Orbit circularized".
    unlock steering.
    unlock throttle.
  }

local function DoRendezvous
  {
// Do a space rendezvous of the ship with a target ship or ship part.
// Assumptions:
//    - Docking is done by The Klaw.
//    - The vessels are almost in the same orbit
//      and are close (eg less than 10km).
// Notes:
//    - Docking using The Klaw does not always work
//      depending on how square The Klaw collides with the
//      target.
//      The script will make multiple docking attempts.
//    - Position calculation might be a little off
//      because the vessel's position is take from the
//      centre of mass (COM), not The Kraw.
//      More research is required eg can the position be
//      calculated from the position of The Klaw part?

    parameter MyTarget.

    local MaxApproachSpeed to 50.0.
    local MinApproachSpeed to 0.5.
    local SafeDistance to 2000. // Make large enough to slow approach gradually.
    local MaxThrustSecs to 5.
    local SteeringSecs to 10.
    local DockingDistance to 50.
    local MaxDockingSpeed to 5.
    local docked to false.
    local KlawArmed to false.
    local ThrottleSet to 0.0.
// Relative Velocity to/from target same as on Nav Ball.
    lock RelVel to ship:velocity:orbit-MyTarget:velocity:orbit.
// Closing speed is negative if moving away.
    lock ClosingSpeed to
      vdot(RelVel,MyTarget:position)/MyTarget:position:mag.
    lock ApproachSpeed to
      min(((MyTarget:position:mag)/SafeDistance)*MaxApproachSpeed,MaxApproachSpeed).
    lock ApproachVel to ApproachSpeed*MyTarget:position:normalized.
    lock ThrustSecs to
      min((MyTarget:position:mag/SafeDistance)*MaxThrustSecs,MaxThrustSecs).
    lock throttle to ThrottleSet.
    print "Run Docking program".
    until docked
      {
        print "Separation: "+round(MyTarget:position:mag/1000,3)+" km "
          +"Safe Approach spd: "+round(ApproachSpeed,1)+" m/s "
          +"Closing spd: "+round(ClosingSpeed,1)+" m/s". 
        if MyTarget:position:mag < DockingDistance
          and RelVel:mag < MaxDockingSpeed
          {
            print "Docking maneuver".
            if not KlawArmed
              {
                print "Arm... THE KLAW!".
                ArmTheKlaw().
                set KlawArmed to true.
              }
            print "Kill relative velocity".
            lock steering to -RelVel.
            wait SteeringSecs.
            set ThrottleSet to 0.01.
            wait until RelVel:mag < 0.1.
            print "Attempt to dock".
            set ThrottleSet to 0.0.
            lock steering to MyTarget:position.
            wait SteeringSecs.
            lock steering to "kill".
            set ThrottleSet to 0.01.
            wait until abs(ClosingSpeed) > 1.
            set ThrottleSet to 0.0.
            wait 30.
// There have been random issues with the "isdead" flag.
            if MyTarget:isdead // Docking will kill the target.
              {
                set docked to true.
                print "Docking successful".
// Workaround for the "extra stage after docking" bug. Docking adds a "stage"
// internally and increments stage:number. A dummy stage() gets rid of it.
                stage.
              }
          }
        else
        if ClosingSpeed < ApproachSpeed*0.9
          and abs(ClosingSpeed) > MinApproachSpeed
          {
            print "Increasing speed towards target".
            lock steering to ApproachVel-RelVel.
            wait SteeringSecs.
            set ThrottleSet to 0.1.
            wait until ClosingSpeed > ApproachSpeed.
          }
        else
        if ClosingSpeed > ApproachSpeed*1.1
          and abs(ClosingSpeed) > MinApproachSpeed
          {
            print "Decreasing speed towards target".
            lock steering to ApproachVel-RelVel.
            wait SteeringSecs.
            set ThrottleSet to 0.1.
            wait until ClosingSpeed < ApproachSpeed.
          }
        else
          {
            print "Coasting to conserve resources".
            set ThrottleSet to 0.0. wait 0. // Switch off engines before steering.
            lock steering to "kill".
            wait ThrustSecs.
          }
        set ThrottleSet to 0.0.
        wait 0.  // Wait for next physics tick.
      }
  }

local function DoRescueKerbin
  {
// Do the Rescue Kerbin contract.

    set target to "Kimemy's Pod".
    DoWarpSpeed("PHYSICS",4).
    wait until vang(ship:up:forevector,target:position) < 90.
    StopWarpSpeed().
    wait until kuniverse:timewarp:issettled. wait 0.
    DoLaunchToOrbit().
    DoVesselIntercept().
    DoDeorbit().
  }

local function DoFlybyMunOld
  {
// Do the Flyby the Mun contract.
// Notes:
//    - This is the "old" Mun Flyby that launches straight up.
//      It has been replaced by a flyby started from a parking orbit.
//    - Free-return trajectory.
//    - The timing of the Launch Window will only be approximate
//      because RAILS timewarping at high rates suffers from overshoot
//      which sometimes creates odd effects.
//    - The phase angle can be tweaked to give different types of
//      flybys and free-return trajectories. Course-correction code may
//      need to be modified to get a survivable atmospheric entry.
    local MyBody to body("Mun").
    local PhaseAng to 75.  // Slow retrograde flyby.
    local RemainingAng to 0.0.
    local LaunchWindowTSpan to timespan(0).
    local LaunchWindowTStmp to timestamp(0).
    local FlybyOrbitHeight to MyBody:altitude+MyBody:radius*3.
    print "Running Flyby The Mun program".
// Wait until the Mun reaches the zenith of the vessel. This gives a reference
// point for the phase angle of the Launch Window.
    print "Waiting for launch window".
    DoWarpSpeed("RAILS",5).
    wait until vang(ship:up:forevector,MyBody:position) < 1.
    StopWarpSpeed().
    wait until kuniverse:timewarp:issettled. wait 0.
// Calculate the start time of the Launch Window.
    set RemainingAng to 
      PhaseAng-vang(ship:up:forevector,MyBody:position).
    set LaunchWindowTSpan to
      timespan(RemainingAng*ship:body:rotationperiod/360).
    set LaunchWindowTStmp to timestamp()+LaunchWindowTSpan.
    DoSafeWait(LaunchWindowTStmp,WarpType).
    print "Launch".
    lock steering to heading(90,90,270).
    stage.
    CreateStagingTrigger().
    lock throttle to 1.
    wait until ship:orbit:apoapsis > FlybyOrbitHeight.
    lock throttle to 0.
    wait until ship:altitude > ship:body:atm:height.
    unlock steering. // Save battery power?
    DoFlyby(10000,"RETROGRADE").
    DoMoonParentReturn().
  }

local function DoOrbitKerbin
  {
// Do the Orbit Kerbin contract.
// Launch into a circular orbit around Kerbin.
// Assumptions:
//    - The rocket has enough delta-v and TWR to reach the orbit height
//      and circularize the orbit.
    local PitchoverStartSecs to 40.
    local PitchoverAng to 10.
    local PitchoverSecs to 7.
    local DragSensibleHeight to 30000.
    local BoostPhaseThrottle to 1.
    local OrbitAlt to 80E3.
    local ApPID to pidLoop().
    set ApPID:kp to 1.
    set ApPID:ki to 0.
    set ApPid:kd to 0.
    set ApPID:minoutput to 0.
    set ApPID:maxoutput to 1.
    set ApPID:epsilon to 0.0.
    set ApPID:setpoint to 45.

    clearscreen.
    print "Launch".
    local StartTimestamp to timestamp(0).
    lock steering to heading(90,90,0).
    lock throttle to 1.
    stage.
    CreateStagingTrigger().
    wait PitchoverStartSecs.
    print "Pitchover".
    lock steering to heading(90,90-PitchoverAng,0).
    wait PitchoverSecs.
    print "Zero-lift gravity turn".
    lock steering to lookdirup(ship:velocity:surface,ship:facing:topvector).
    lock throttle to BoostPhaseThrottle.
    wait until ship:orbit:apoapsis > OrbitAlt*0.90.
    wait ship:altitude > DragSensibleHeight.
    print "Orbit circularization".
    lock steering to lookdirup(ship:velocity:orbit,ship:facing:topvector).
    lock throttle to ApPID:update(timestamp():seconds,eta:apoapsis).
    wait until ship:periapsis > OrbitAlt.
    print "Desired orbit achieved".
    lock throttle to 0.
    DoVesselScienceExperiments().
    return.
//    DoVesselIntercept().
//    set StartTimestamp to timestamp().
//    until timestamp() > StartTimestamp+timespan(1200)
//      {
//        GoEVA().
//        wait 5.
//        DoWarpSpeed("PHYSICS",4).
//        wait 20.
//        StopWarpSpeed().
//      }
    lock steering to lookdirup(-ship:velocity:orbit,ship:facing:topvector).
    wait 10.
    lock throttle to 1.
    wait until stage:number = 0.
    lock steering to lookdirup(-ship:velocity:surface,ship:facing:topvector).
    chutes on.
    unlock throttle.
//    wait until ship:altitude < ship:body:atm:height-1000.
//    GoEVA().
//    wait 5.
//    DoWarpSpeed("PHYSICS").
    wait until (ship:status="LANDED" or ship:status="SPLASHED").
    StopWarpSpeed().
    unlock steering.
    wait 2.
//    GoEVA().
  }

local function DoSuborbitalSpaceflight
  {
// Do the Suborbital Spaceflight contract.
// Assumptions:
//    - The rocket gets above the atmosphere.
    lock steering to heading(0,75,0).
    stage.
    CreateStagingTrigger().
//    DoWarpSpeed("PHYSICS",4).
    wait until ship:verticalspeed < 0.
//    StopWarpSpeed().
//    DoVesselScienceExperiments().
    GoEVA().
    wait 5.
    unlock steering.
    chutes on.
//    DoWarpSpeed("RAILS",4).
    wait until ship:altitude < ship:body:atm:height-1000.
    GoEVA().
    wait 5.
//    DoWarpSpeed("PHYSICS",4).
    wait until (ship:status="LANDED" or ship:status="SPLASHED").
//    StopWarpSpeed().
    wait 1. 
    DoVesselScienceExperiments().
    wait 5.
    GoEVA().
  }

local function DoLaunchPad
  {
// Do basic stuff after spawning on a launch pad.

    DoVesselScienceExperiments().
    wait 1.
    GoEVA().
  }

local function DoPeAdjustment
  {
// Adjust the periapsis of the ship's orbit.

    parameter PeAlt.
    parameter SteeringSecs.

    print "Adjust periapsis to: "+round(PeAlt/1000,3)+" km".

    if ship:orbit:periapsis > PeAlt
      {
        lock steering to -ship:velocity:orbit.
        wait SteeringSecs.
        lock throttle to
          min(abs(PeAlt-ship:orbit:periapsis)/PeAlt+0.001,1.0).
        wait until ship:orbit:periapsis < PeAlt.
      }
    else
      {
        lock steering to ship:velocity:orbit.
        wait SteeringSecs.
        lock throttle to
          min(abs(PeAlt-ship:orbit:periapsis)/PeAlt+0.001,1.0).
        wait until ship:orbit:periapsis > PeAlt.
      }
    unlock throttle.
  }

local function DoPeAdjustmentRadial
  {
// Adjust the periapsis and prograde/retrograde of the ship's orbit
// by thrusting in the radial direction.
// Notes:
//    - 

    parameter PeAlt.
    parameter OrbitType. // PROGRADE, RETROGRADE, DONTCARE
    parameter SteeringSecs.

    local NormalVec to
      vcrs(ship:position-ship:body:position,ship:velocity:orbit).
    local RadialOutVec to vcrs(ship:velocity:orbit,NormalVec).
    local MyPrograde to false.

    if OrbitType <> "PROGRADE"
      and OrbitType <> "RETROGRADE"
      and OrbitType <> "DONTCARE"
      print 0/0. // Unknown Orbit Type

    print "Adjust periapsis to: "+round(PeAlt/1000,3)+" km"+" "+OrbitType.

    set MyPrograde to ship:orbit:inclination>=0.0 and ship:orbit:inclination<90.0.

    if (MyPrograde and OrbitType="RETROGRADE")
        or (not MyPrograde and OrbitType="PROGRADE")
      {
// This code works because KSP allows "negative" Pe values.
        lock steering to -RadialOutVec.
        wait SteeringSecs.
        lock throttle to
          min(abs(PeAlt-ship:orbit:periapsis)/PeAlt+0.001,1.0).
        wait until ship:orbit:periapsis < 0. // Pe goes below sea level.
        wait until ship:orbit:periapsis > PeAlt.
      }
    else
    if ship:orbit:periapsis > PeAlt
      {
        lock steering to -RadialOutVec.
        wait SteeringSecs.
        lock throttle to
          min(abs(PeAlt-ship:orbit:periapsis)/PeAlt+0.001,1.0).
        wait until ship:orbit:periapsis < PeAlt.
      }
    else
      {
        lock steering to RadialOutVec.
        wait SteeringSecs.
        lock throttle to
          min(abs(PeAlt-ship:orbit:periapsis)/PeAlt+0.01,1.0).
        wait until ship:orbit:periapsis > PeAlt.
      }
    unlock throttle.
    unlock steering.
  }