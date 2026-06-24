// Name: FlySputnik1V01
// Author: JitteryJet
// Version: V01
// kOS Version: 1.6.0.1
// KSP Version: 1.12.5
// Description:
//    Fly the Sputnik 1 satellite.
//
// Assumptions:
//    - Body is Earth.
//    - 
//
// Notes:
//    -
//
// Todo:
//    - Finalise script.
//    -
//
// Update History:
//    24/06/2026 V01  - Created. WIP.
//                    -
//
@lazyglobal off.
// Constants.
local RealtimeSecs to 0.0.
local PeriodSecs to 0.21.

// SKID chip values for Sputnik 1 "beep-beep".
local v0 to getvoice(0).
set v0:volume to 0.2.
set v0:wave to "square".
set v0:attack to 0.0.
set v0:decay to 0.0.
set v0:sustain to 1.0.
set v0:release to 0.0.
local note0 to note(1000.0,99).

sas off.
rcs off.
clearscreen.

// Program identification.
print "Program function: Fly Sputnik 1".
print "Ship name: "+ship:name.
print " ".

until false
  {
// Syncronize the period of the on/off tone with
// the realtime clock as the game time clock varies
// causing it to sound terrible.
// The human ear can tell.
    set RealtimeSecs to kuniverse:realtime.
    v0:play(note0).
    wait until kuniverse:realtime>RealtimeSecs+PeriodSecs.
    v0:stop().
    wait until kuniverse:realtime>RealtimeSecs+2*PeriodSecs.
  }

print "Program completed".