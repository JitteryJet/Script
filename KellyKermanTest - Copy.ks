local TargetName to "Phoenix".
local MaxApproachSpeed to 100.
local MaxBangBangTime to 3.
local MaxHysteresisSpeed to MaxApproachSpeed*0.15.
local SafeDistance to 5000.
local TurnToTime to 3.0.

set target to vessel(TargetName).
set VesselTarget to vessel(TargetName).
set CrewCabinTarget to vessel(TargetName).

lock RelativeVelVec to VesselTarget:velocity:orbit-ship:velocity:orbit.
lock PositionVec to CrewCabinTarget:position.
lock ClosingSpeed to vdot((ship:velocity:orbit-VesselTarget:velocity:orbit),PositionVec)/PositionVec:mag.
lock ApproachSpeed to min((PositionVec:mag/SafeDistance)*MaxApproachSpeed+1.0,MaxApproachSpeed).
lock ApproachVelVec to PositionVec:normalized*5.0-RelativeVelVec.  // This is BS, but it sort of works.
lock BangBangTime to min((PositionVec:mag/SafeDistance)*MaxBangBangTime,MaxBangBangTime).
lock HysteresisSpeed to min((PositionVec:mag/SafeDistance)*MaxHysteresisSpeed,MaxHysteresisSpeed).

addons:eva:toggle_rcs(true).
addons:eva:turn_to(RelativeVelVec).
wait TurnToTime.

until PositionVec:mag <= 1.0
  {
    print round(ClosingSpeed,1)+" "+round(PositionVec:mag/1000,3)+" "+BangBangTime.
    if VesselTarget:unpacked
      {
        set CrewCabinTarget to vessel(TargetName):partstagged("Kelly Kerman Target")[0].
      }
    else
      {
        set CrewCabinTarget to vessel(TargetName).
      }
    if ClosingSpeed > ApproachSpeed
      {
        addons:eva:turn_to(ApproachVelVec).
        wait TurnToTime.
        addons:eva:move("backward").
        wait BangBangTime.
        addons:eva:move("stop").
      }
    else
    if ClosingSpeed > (ApproachSpeed-HysteresisSpeed)
      {
        addons:eva:turn_to(ApproachVelVec).
        wait TurnToTime.
      }
    else
    if ClosingSpeed >= 0
      {
        addons:eva:turn_to(ApproachVelVec).
        wait TurnToTime.
        addons:eva:move("forward").
        wait BangBangTime.
        addons:eva:move("stop").
      }
    else
      {
        addons:eva:turn_to(-ApproachVelVec).
        wait TurnToTime.
        addons:eva:move("forward").
        wait BangBangTime.
        addons:eva:move("stop").
      }
  }
addons:eva:move("stop").
addons:eva:toggle_rcs(false).
until false
  {
    addons:eva:ladder_grab.
    wait 5.
    addons:eva:board.
  }


