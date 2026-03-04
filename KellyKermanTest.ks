local TargetName to "Phoenix".
local MaxApproachSpeed to 100.
local MaxBangBangTime to 5.0.
local StopTime to 1.0.
local MaxHysteresisSpeed to MaxApproachSpeed*0.2.
local SafeDistance to 3000.
local TurnToTime to 0.5.
local action to "".

set target to vessel(TargetName).
set VesselTarget to vessel(TargetName).
set CrewCabinTarget to vessel(TargetName).

lock RelativeVelVec to VesselTarget:velocity:orbit-ship:velocity:orbit.
lock PositionVec to CrewCabinTarget:position.
lock ClosingSpeed to vdot((ship:velocity:orbit-VesselTarget:velocity:orbit),PositionVec)/PositionVec:mag.
lock ApproachSpeed to min((PositionVec:mag/SafeDistance)*MaxApproachSpeed+0.1,MaxApproachSpeed).
lock ApproachVelVec to PositionVec:normalized*ApproachSpeed-RelativeVelVec.  // This is BS, but it sort of works.
lock BangBangTime to min((PositionVec:mag/SafeDistance)*MaxBangBangTime+0.1,MaxBangBangTime).
lock HysteresisSpeed to min((PositionVec:mag/SafeDistance)*MaxHysteresisSpeed,MaxHysteresisSpeed).

set action to "Jump-off".
addons:eva:toggle_rcs(true).
addons:eva:turn_to(RelativeVelVec).
wait TurnToTime.

until PositionVec:mag <= 1.5
  {
    print action+" "+round(ClosingSpeed,1)+" "+round(PositionVec:mag/1000,3)+" "+round(BangBangTime,3).
    if VesselTarget:unpacked
      {
        set CrewCabinTarget to vessel(TargetName):partstagged("Kelly Kerman Target")[0].
        set target to vessel(TargetName).
      }
    else
      {
        set CrewCabinTarget to vessel(TargetName).
        set target to CrewCabinTarget.
      }
    if vdot(PositionVec,RelativeVelVec) > 0
      {
// Target moving away.
        set action to "Kill rel vel".
        addons:eva:turn_to(RelativeVelVec).
        wait TurnToTime.
        addons:eva:move("forward").
        wait BangBangTime.
        addons:eva:move("stop").
        wait StopTime.
      }
    else
      {
// Target moving towards.
        if RelativeVelVec:mag > ApproachSpeed
          {
           set action to "Slow down".
           addons:eva:turn_to(-RelativeVelVec).
           wait TurnToTime.
           addons:eva:move("backward").
           wait BangBangTime.
           addons:eva:move("stop").
           wait StopTime.
          }
        else
        if RelativeVelVec:mag > (ApproachSpeed-HysteresisSpeed)
          {
           set action to "Coast".
           addons:eva:turn_to(PositionVec).
           wait TurnToTime.
           wait StopTime.
          }
        else
        if RelativeVelVec:mag >= 0
          {
            set action to "Speed up".
//            AlignVelocityToTarget().
            addons:eva:turn_to(PositionVec).
            wait TurnToTime.
            addons:eva:move("forward").
            wait BangBangTime.
            addons:eva:move("stop").
            wait StopTime.
          }
        else
          {
            print 0/0.
          }
      }
    if PositionVec:mag < 1.5
      {
        addons:eva:move("stop").
        addons:eva:ladder_grab.
        addons:eva:board.
      }  
  }

local function AlignVelocityToTarget
  {
    local PrevAngle to 999.
    local angle to 0.
    set angle to vang(-RelativeVelVec,PositionVec).
    until angle > PrevAngle
      or angle < 10
      {
        print "Align vel to target"+" "+round(angle,2).
        if vdot(PositionVec,RelativeVelVec) > 0
          return.  // Failsafe.
        set PrevAngle to angle.
        addons:eva:turn_to(PositionVec).
        wait TurnToTime.
        addons:eva:move("forward").
        wait BangBangTime.
        addons:eva:move("stop").
        set angle to vang(-RelativeVelVec,PositionVec).
      }
  }
