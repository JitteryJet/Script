// CareerEp07.
@lazyglobal off.

ExploreTheMun().

local function ExploreTheMun
  {
// Contract to "Explore The Mun".
    sas off.
//    set ship:control:pilotmainthrottle to 0.
    local PhaseAngle to 30.
    local ThrottleSet to 0.
    local TimeToSOI to 0.
    set target to mun.
    set kuniverse:timewarp:rate to 100.
// Wait for zenith. The Mun will pass overhead.
    until vang(ship:up:forevector,target:position) < 1
      {wait 0.}
// Wait for post-Zenith phase angle.
    until vang(ship:up:forevector,target:position) > PhaseAngle
      {wait 0.}
    kuniverse:timewarp:cancelwarp().
    until kuniverse:timewarp:issettled {wait 0.}
    lock steering to lookdirup(ship:up:forevector,ship:facing:topvector).
    lock throttle to ThrottleSet.
    set ThrottleSet to 1.
    SetStagingTrigger().
    until ship:apoapsis > target:altitude
      {wait 0.}
    set ThrottleSet to 0.
    unlock steering.
    wait 5.
    set TimeToSOI to eta:transition.
    kuniverse:timewarp:warpto(time:seconds+TimeToSOI).
    wait TimeToSOI.
    until kuniverse:timewarp:issettled {wait 0.}
    wait 5.
    stage.
    DoScienceExperiments().
    wait 5.
    set TimeToSOI to eta:transition.
    kuniverse:timewarp:warpto(time:seconds+TimeToSOI).
    wait TimeToSOI.
    until kuniverse:timewarp:issettled {wait 0.}
    wait 5.
    set kuniverse:timewarp:rate to 1000.
    until ship:altitude < 2000000
      {wait 0.}
    kuniverse:timewarp:cancelwarp().
    until kuniverse:timewarp:issettled {wait 0.}
    until ship:altitude < 100000
      {wait 0.}
    lock steering to -ship:velocity:orbit.
    set ThrottleSet to 1.
    wait until false.
    set ship:control:pilotmainthrottle to 0.
  }

local function TestChuteInFlightOverKerbin
  {
// Contract to "Test Parachute in flight over Kerbin".
    sas on.
    set ship:control:pilotmainthrottle to 0.
    lock throttle to 1.
    stage.
    wait until ship:maxthrust = 0.
    stage.
    wait until ship:altitude >= 11000
    and ship:altitude <= 15000
    and ship:airspeed >= 10
    and ship:airspeed <= 100.
    stage.
  }

local function OrbitKerbin
  {
// Contract to "Orbit Kerbin".
    sas off.
    set ship:control:pilotmainthrottle to 0.
    local TurnStartAlt to 1400.
    local ThrottleDownAlt to 15000.
    local PitchOverAng to 10.
    local ShipLaunchAlt to ship:altitude.
    lock steering to heading(90,90,-90).
    lock throttle to 1.
    SetStagingTrigger().
    wait until ship:altitude > ShipLaunchAlt+TurnStartAlt.
    lock steering to heading(90,90-PitchOverAng,-90).
    wait 10.
    lock steering to ship:velocity:surface.
    lock throttle to min(1,ThrottleDownAlt/ship:altitude).
    wait until ship:apoapsis > ship:body:atm:height+1000.
    lock throttle to 0.
    wait until ship:altitude > ship:body:atm:height.
    lock steering to heading(90,0,-90).
    lock throttle to 1.
    wait until ship:periapsis > ship:body:atm:height
      and ship:apoapsis > ship:body:atm:height.
    lock throttle to 0.
    DoScienceExperiments().
  }

local function EscapeTheAtmosphere
  {
// Contract to "Escape the atmosphere".
    sas on.
    stage.

    wait until ship:altitude > ship:body:atm:height.
    wait 0.

    DoScienceExperiments().

    stage.
    wait until stage:ready.
    stage.
  }

local function DoScienceExperiments
  {
// Do Scientific Experiments on a vessel.
    local ModuleList to ship:modulesnamed("ModuleScienceExperiment").
    for module in ModuleList
      {
        module:deploy.
        wait until module:hasdata.
      }
  }

local function SetStagingTrigger
  {
// Automatically activate the next stage when the current stage
// can no longer produce thrust or has ran out of fuel.
    local lock FuelInStage to stage:liquidfuel+stage:solidfuel.
    when
      ship:maxthrust = 0
      or FuelInStage = 0
    then
      {
        stage.
        until stage:ready {wait 0.}
        if stage:number > 0
          return true.
        else
          return false.
      }
  }