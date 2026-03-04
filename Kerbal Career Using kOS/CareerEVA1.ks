// CareerEVA1. Career Mode EVA script.
// Used in the the "Kerbal Career Using kOS" YouTube series.
// Notes:
//    - After spawning, a Kerbal runs it's own script independent
//      of the vessel it spawned from.

@lazyglobal off.
runoncepath("Archive:/Kerbal Career Using kOS/CareerLib1").
runoncepath("GeoCoordinates V04").
local WarpType to "NOWARP".  // NOWARP,PHYSICS,RAILS.
LoadAnimations().

local VesselName to "Lander Mun".
local VesselVar to vessel(VesselName).

//wait 10. LaunchKerbalToOrbit().
//DoKerbalEVAScience().
//wait 5. DoKerbalDropMission().
DoKerbalScienceFromCrewHatch().

local function DoKerbalDropMission
  {
// Do the kerbal drop mission.

//    LandKerbalFromOrbit().
//    LaunchKerbalToOrbit().
    WaitForMotherShip(VesselVar).
  }

local function WaitForMotherShip
  {
// Wait for the mother ship to come within rendezvous range.

    parameter MotherShip.

    local DockingDistance to 15000.

    print "Running Wait For Mother Ship program".
    print "Target name: "+Mothership:name.
    print "Waiting for a close approach: "
      +round(DockingDistance/1000,2)+" km".
    wait 1. // Workaround for phantom acceleration warping bug.
//    DoWarpSpeed(WarpType,4).
    until MotherShip:position:mag < DockingDistance
      {
        wait 0.
      }
//    StopWarpSpeed().

// Make the mother ship the active vessel. 
    set kuniverse:activevessel to VesselVar.
  }

local function LaunchKerbalToOrbit
  {
// Launch a kerbal into orbit.

    local BurnVec to v(0,0,0).
    local ManeuverpointTStmp to timestamp(0).

    print "Running Launch Kerbal To Orbit program".
    addons:eva:jump().
    wait 1.
    set addons:eva:rcs to true.
    wait 1.
    addons:eva:move("forward").
    until ship:orbit:apoapsis > 9000
      {
        addons:eva:turn_to(heading(90,25):forevector:normalized).
        wait until addons:eva:state<>"turn_to".
      }
    addons:eva:move("stop").
    set addons:eva:rcs to false.
    set ManeuverpointTStmp to timestamp()+ETA:apoapsis.
    print "Ap ETA: "+ManeuverpointTStmp:full.
    wait 1. // Workaround for phantom acceleration warping bug.
    if WarpType<>"NOWARP"
      DoSafeWait(ManeuverpointTStmp,"PHYSICS").
    else
      DoSafeWait(ManeuverpointTStmp,"NOWARP").
    set BurnVec to ship:velocity:orbit:normalized.
    set addons:eva:rcs to true.
//    wait 5.
    addons:eva:turn_to(BurnVec).
    wait until addons:eva:state<>"turn_to".
    addons:eva:move("forward").
    until ship:orbit:periapsis > 8500
      {
        addons:eva:turn_to(BurnVec).
        wait until addons:eva:state<>"turn_to".
        wait 0.
      }
    addons:eva:move("stop").
    set addons:eva:rcs to false.
    print "Launch Kerbal To Orbit completed".
  }

local function LandKerbalFromOrbit
  {
// Land a kerbal on the surface from a parking orbit.
// Assumptions:
//    - The terrain below the kerbal is more-or-less flat.
// Notes:
//    - The kerbal has to EVA at a low altitude (eg 10km) to avoid running
//      out of propellant.
//    - The kerbal may be out of control for a number of seconds after
//      colliding with the surface. Control may never be recovered.
//      This appears to be related to the KSP finite state machine.
//    - It is likely the kerbal does not fly straight!
// ToDo:
//    - Attempt to add a simple suicide burn to reduce fuel usage.
//    - Add flip to vertical orientation just prior to landing.
//    - Result are dependent on what camera mode is used at the
//      start! Investigate why this is the case. Orbital camera mode
//      currently gives the best results.

    local MaxSafeSpeed to 75.
    local MinSafeSpeed to 2.
    local SafeAlt to 1500.
    lock SafeSpeed to
      min((alt:radar/SafeAlt)*MaxSafeSpeed+MinSafeSpeed,MaxSafeSpeed).
    local thrusting to false.
    local TurnToVec to v(0,0,0).
    local thrust to 270.  // Around 270 Newtons.
    local acceleration to 0.0.
    local BurnSecs to 0.0.
    local DeltaV to 0.0.
    local BurnVec to v(0,0,0).
    local ManeuverpointTStmp to timestamp(0).
    local BurnEndTStmp to timestamp(0).

    print "Running Land Kerbal program".
    print "Kerbal name: "+ship:name.
    print "Let go crew hatch".
    addons:eva:ladder_release.
    print "Move away from crew hatch".
    set addons:eva:rcs to true.
    wait 1.
    addons:eva:move("backward").
    wait 1.
    addons:eva:move("stop").
    wait 2.
    print "Orient kerbal".
    addons:eva:turn_to(ship:up:forevector:normalized).
    wait until addons:eva:state<>"turn_to".
    wait 5.
// The burn will only be approximate.
    set acceleration to thrust/(ship:mass*1000).
    set DeltaV to ship:velocity:orbit:mag.
    set BurnSecs to DeltaV/acceleration.
    print "Deorbit calculations:".
    print round(DeltaV,1)+"m/s "+round(BurnSecs,1)
      +"secs "+round(ship:mass*1000,2)+"kg "
      +round(acceleration/constant:g0,2)+"g".
// Burn perpendicular to the surface at the calculated maneuver point.
// This is more efficient than following the velocity vector???
// The calculation are based on the orbital frame.
    set ManeuverpointTStmp to timestamp()+BurnSecs/2.
    set BurnVec to -velocityat(ship,ManeuverpointTStmp):orbit.
    Print "Deorbit burn started".
    set BurnEndTStmp to timestamp()+BurnSecs.
    addons:eva:move("forward").
    until timestamp() > BurnEndTStmp
      {
        addons:eva:turn_to(BurnVec:normalized).
        wait until addons:eva:state<>"turn_to".
      }
    addons:eva:move("stop").
    print "Deorbit burn completed".

// The assumption is the kerbal is falling more-or-less
// vertically by this point.
    until ship:status="LANDED"
      {
        if ship:orbit:velocity:surface:mag < SafeSpeed*0.95
          and thrusting
          {
            addons:eva:move("stop").
            set thrusting to false.
          }
        else
        if ship:orbit:velocity:surface:mag > SafeSpeed*1.05
          and not thrusting
          {
            addons:eva:move("forward").
            set thrusting to true.
          }
        else
          {
          }
        if thrusting
          {
            set TurnToVec to -ship:orbit:velocity:surface.
            addons:eva:turn_to(TurnToVec:normalized).
            wait until addons:eva:state<>"turn_to".
          }
        wait 0.
      }
// Attempt to cancel any "stuck" commands after colliding with the surface.
// The kerbal might bounce several times.
   until addons:eva:state<>"ragdoll"
      and addons:eva:state<>"recover"
      and addons:eva:state<>"turn to heading"
      {
//        print addons:eva:state.
        wait 0.
      }
//    wait 5. // Workaround for the bouncing nonsense.
    print addons:eva:state.
    set addons:eva:neutralize to true.
    set addons:eva:rcs to false.
    print "The kerbal has landed".
    wait 2.
    DoKerbalExperiment("eva report").
    DoKerbalExperiment("take surface sample").
    addons:eva:move("forward").
    wait 10.
    addons:eva:move("stop").
    wait 3.
    addons:eva:plantflag("Here","For All Kerbalkind").
    wait 10.
    addons:eva:turn_right(90).
    addons:eva:move("forward").
    wait 2.
    addons:eva:move("stop").
    addons:eva:turn_left(90).
    wait 1.
    PlayKerbalSalute().
//    PlayKerbalArseScratch().
    DoKerbalExperiment("perform eva science").
    print "Land Kerbal program completed".
  }

local function DoKerbalIntercept
  {
// Intercept another vessel using a spacewalk.
    local MaxApproachSpeed to 50.
    local SafeDistance to 3000.
    local MaxThrustTime to 2.
// Select Rescuer or Rescuee as the target of the spacewalk.
    if ship:name = "Jebediah Kerman"
      set target to "Sury's Craft".
    else
    if ship:name = "Sury Kerman"
      set target to "Rescue Kerbin".
    else
      print 0/0. // Kerbal not found.
// Relative Velocity to/from target same as on Nav Ball.
    lock RelVel to ship:velocity:orbit-target:velocity:orbit.
    lock ClosingSpeed to
      vdot(RelVel,target:position)/target:position:mag.
    lock ApproachSpeed to
      min((target:position:mag/SafeDistance)*MaxApproachSpeed+0.5,MaxApproachSpeed).
    lock ApproachVel to ApproachSpeed*target:position:normalized.
    lock ThrustTime to
      min((target:position:mag/SafeDistance)*MaxThrustTime+0.1,MaxThrustTime).
    local ThrustVec to v(0,0,0).
    print "Let go crew hatch".
    addons:eva:ladder_release.
    wait 1.
    print "Move away from crew cabin".
    addons:eva:toggle_RCS(true).
    addons:eva:move("backward").
    wait 2.
    addons:eva:move("stop").
    addons:eva:turn_to(target:position).
    wait 2.
    until target:position:mag < 1.5
      {
        if vdot(RelVel,target:position) < 0
          {
            print "Kill velocity away from target"+
              " "+round(ClosingSpeed,1).
            set ThrustVec to ApproachVel-RelVel.
            addons:eva:turn_to(ThrustVec).
            wait 0.25.
            addons:eva:move("forward").
            wait ThrustTime.
            addons:eva:move("stop").
          }
        else
          {
            if ClosingSpeed < ApproachSpeed*0.95
              {
                print "Increase speed towards target"+
                  " "+round(ClosingSpeed,1).
                set ThrustVec to ApproachVel-RelVel.
                addons:eva:turn_to(ThrustVec).
                wait 0.25.
                addons:eva:move("forward").
                wait ThrustTime.
                addons:eva:move("stop").
              }
            else
            if ClosingSpeed > ApproachSpeed*1.05 
              {
                print "Decrease speed towards target"+
                  " "+round(ClosingSpeed,1).
                set ThrustVec to ApproachVel-RelVel.
                addons:eva:turn_to(-ThrustVec).
                wait 0.25.
                addons:eva:move("backward").
                wait ThrustTime.
                addons:eva:move("stop").
              }
            else
              {
                print "Coast to save fuel"
                  +" "+round(ClosingSpeed,1).
                wait 5.
              }
          }
        wait 0.
      }
    print "Spacewalk completed".
    addons:eva:toggle_RCS(true).
//    print "Switching vessel".
//    set kuniverse:activevessel to target.
    addons:eva:goeva(target:crew[0]).
    print "Finished".
  }

local function DoKerbalEVAScience
  {
// Collect the Kerbal EVA science depending on the situation of
// the ship.
// Notes:
//    - "PRELAUNCH" is the special case of a ship spawned on a launchpad or
//      airstrip using the "launch" menu option.
//    

    if VesselVar:status="PRELAUNCH"
      {
        DoKerbalScienceFromCrewHatch().
      }
    else
    if VesselVar:status="LANDED"
      {
        DoKerbalScienceAfterLanding().
      }
    else
    if VesselVar:status="SPLASHED"
      {
        DoKerbalScienceAfterSplashdown().
      }
    else
    if VesselVar:status="ORBITING"
      {
        DoKerbalScienceFromCrewHatch().
      }
    else
    if VesselVar:status="SUB_ORBITAL"
      {
        DoKerbalScienceFromCrewHatch().
      }.
    if VesselVar:status="FLYING"
      {
        DoKerbalScienceFromCrewHatch().
      }.
    if VesselVar:status="ESCAPING"
      {
        DoKerbalScienceFromCrewHatch().
      }.
  }

local function DoKerbalTask
  {
// Do the task assigned to the Kerbal running this script.

    if ship:name = "Jebediah Kerman"
      CollectKerbalScience(KSCRunwayGeo,VesselVar).
    else
    if ship:name = "Bill Kerman"
      CollectKerbalScience(KSCFlagpoleGeo,VesselVar).
    else
    if ship:name = "Bob Kerman"
      CollectKerbalScience(KSCVABGeo,VesselVar).
    else
    if ship:name = "Valentina Kerman"
      CollectKerbalScience(KSCVABPodMemorialGeo,VesselVar).
  }

local function DoKerbalScienceFromCrewHatch
  {
// Do Kerbal science experiments after an EVA while still attached
// to the crew hatch.
// Notes:
//    - A surface sample can be taken while still attached to the crew
//      hatch which is surprising - BUT a surface sample taken while
//      not on the surface is invalid, will display an error message
//      and not set the hasdata flag.
// Assumptions:
//    - The is attached to the crew hatch.
//    - The rootpart is the command cabin.
    DoKerbalExperiment("eva report").
    if VesselVar:status="LANDED" or VesselVar:status="SPLASHED"
      DoKerbalExperiment("take surface sample").
    wait 1.
    StoreKerbalExperiments(VesselVar:rootpart).
    wait 10.
    BoardKerbal().
  }

local function DoKerbalScienceAfterLanding
  {
// Do Kerbal science experiments after landing.
// Assumptions:
//    - The Kerbal has spawned from a landed ship and has a ladder
//      from the crew cabin to the surface.
//    - The rootpart is the command cabin.
// Notes:
//    - Interference from objects such as the flag and capsule
//      seem to cause odd effects when moving. Try turn_right(0)
//      instead of move("stop") to set the Kerbal to an idle state.
//      Allow enough time for movement changes to complete especially
//      when the Kerbal approaches objects it interacts with.
// Todo:
//    - Need more investigation on how to control Kerbal on
//      ladder etc.
    local CrewCabin to VesselVar:rootpart.
    local ladder to CrewCabin:partsnamed("ladder1")[0].
    DoKerbalExperiment("eva report").
    DoKerbalExperiment("take surface sample").
    wait 5.
    addons:eva:move("down").
    wait 1.
    addons:eva:move("stop").
    addons:eva:ladder_release.
    addons:eva:move("backward").
    wait 1.
    addons:eva:move("stop").
    addons:eva:turn_right(180).
    addons:eva:move("forward").
    wait 10.
    addons:eva:move("stop").
    wait 3.
    addons:eva:plantflag("Here","For All Kerbalkind").
    wait 10.
    addons:eva:turn_right(90).
    addons:eva:move("forward").
    wait 2.
    addons:eva:move("stop").
    addons:eva:turn_left(90).
    wait 1.
    PlayKerbalSalute().
    PlayKerbalArseScratch().
    DoKerbalExperiment("perform eva science").
    addons:eva:turn_to(ladder:position).
    set addons:eva:sprint to true.
    addons:eva:move("forward").
    until ladder:position:mag < 0.5
      {
        addons:eva:turn_to(ladder:position).
        wait 0.
      }
    print ladder:position:mag.
    set addons:eva:sprint to false.
    addons:eva:move("stop").
    wait 1.
    addons:eva:turn_left(0).  // Stop sometimes won't work near capsule.
    wait 1.
    StoreKerbalExperiments(CrewCabin).
    wait 1.
    addons:eva:ladder_grab.
    wait 1.
    print CrewCabin:position:mag.
    addons:eva:move("up").
    wait 2.
    addons:eva:move("stop").
    wait 1.
    BoardKerbal().
  }

local function DoKerbalScienceAfterSplashdown
  {
// Do Kerbal science experiments after splash down.
// Assumptions:
//    - The Kerbal has spawned from a splashed ship.
    DoKerbalExperiment("eva report").
    DoKerbalExperiment("take surface sample").
    wait 5.
    BoardKerbal().
  }

local function CollectKerbalScience
  {
// Collect Kerbal science from a specified Geographic coordinate
// and return it to the Crew Cabin.
// Assumptions:
//    - The rootpart is the crew cabin.

    parameter geo.
    parameter CrewCabin.

    wait 5.
    addons:eva:move("down").
    wait 1.
    addons:eva:move("stop").
    addons:eva:ladder_release.
    addons:eva:move("backward").
    wait 1.
    addons:eva:turn_right(90).
    addons:eva:move("forward").
    wait 1.
    addons:eva:move("stop").
    PlayKerbalWave().
    addons:eva:move("forward").
    wait 7.
//    DoWarpSpeed().
//    set addons:eva:sprint to true.
    addons:eva:move("forward"). 
    until geo:position:mag < 10
      {
        addons:eva:turn_to(geo:position).
        wait 0.5.
      }
    addons:eva:move("stop").
    wait 1.
    DoKerbalExperiment("eva report").
    wait 1.
    DoKerbalExperiment("take surface sample").
    wait 1.
//    DoKerbalExperiment("perform eva science").
//    wait 1.
    addons:eva:runaction("jump start").
    addons:eva:runaction("jump end").
    wait 1.
//    DoWarpSpeed().
//    set addons:eva:sprint to true.
    addons:eva:move("forward").
    until CrewCabin:position:mag < 2
      {
        addons:eva:turn_to(CrewCabin:position).
        wait 0.5.
      }
    set addons:eva:sprint to false.
    addons:eva:move("stop").
    addons:eva:stopallanimations.
    StoreKerbalExperiments(CrewCabin:rootpart).
    wait 1.
    addons:eva:move("left").
    wait 10.
    addons:eva:move("stop").
    addons:eva:stopallanimations.
    wait 1.
    addons:eva:runaction("playing golf").
    addons:eva:move("forward").
    wait 40.
    addons:eva:move("stop").
    addons:eva:stopallanimations.
  }

local function JetpackToOrbit
  {
// Jetpack to orbit.
// Notes:
//    - The Kerbal has to be off the ground by around xxxx metres for
//      the jetpack to work.

    local TurnVec to v(0,0,0).

    wait 5.
    addons:eva:move("down").
    wait 1.
    addons:eva:move("stop").
    addons:eva:ladder_release.
    addons:eva:move("backward").
    wait 1.
    addons:eva:turn_right(90).
    addons:eva:move("forward").
    wait 1.
    addons:eva:move("stop").
    addons:eva:move("forward").
    wait 7.
    addons:eva:move("stop").
    wait 2.
    addons:eva:turn_left(0). // Required to stop walking?
    wait 2.
    addons:eva:runaction("jump start").
    wait 1.
    addons:eva:toggle_RCS(true).
    wait 1.
    set TurnVec to heading(90,45):forevector.
    addons:eva:turn_to(TurnVec).
    wait 1.
    addons:eva:move("forward").
  }