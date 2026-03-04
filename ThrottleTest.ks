// Test the throttle windup and decay.
@lazyglobal off.
set config:ipu to 2000.
local ThrottleSet to 0.0.
lock throttle to ThrottleSet.
set ThrottleSet to 1.
until ship:thrust >= ship:availablethrust
  {
    print ship:thrust.
    wait 0.
  }

set ThrottleSet to 0.
until ship:thrust = 0
  {
    print ship:thrust.
    wait 0.
  }