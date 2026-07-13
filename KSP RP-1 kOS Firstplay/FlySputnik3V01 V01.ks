// Name: FlySputnik3V01
// Author: JitteryJet
// Version: V01
// kOS Version: 1.6.0.1
// KSP Version: 1.12.5
// Description:
//    Fly the Sputnik 3 satellite.
//
// Assumptions:
//    - Body is Earth.
//    - 
//
// Notes:
//    -
//
// Todo:
//    -
//
// Update History:
//    14/07/2026 V01  - Created.
//                    -
//
@lazyglobal off.

// Load in functions from the library.
runoncepath("archive:/library/AudioSputnik1Beep V01").
runoncepath("archive:/library/MiscFunctions V07").

sas off.
rcs off.
clearscreen.

// Program identification.
print "Program function: Fly Sputnik 3 satellite".
print "Ship name: "+ship:name.
print " ".

print "The satellite that goes 'beep'".
DoSputnik1Beep(60).

// Satify Contract conditions, collect Science.
print "Collecting Science".
DoSafeWait(timestamp()+36000,"RAILS").

print "Program completed".