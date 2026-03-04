// Program Title: DunaAndReturn
// Author: JitteryJet
// Version: V01
// kOS Version: 1.3.2.0
// KSP Version: 1.11.2
// Description:
//  Launch a vessel from Kerbin to Duna and return.
//
// Notes:
//    - Each step is checkpointed with a savegame at completion
//      to allow the script to be restarted at any step.
//    - Sometimes a WAIT is required before a quicksave.
//
// Todo
//    -
//
// Update History:
//    30/03/2021 V01  - Created. WIP.
//
@lazyglobal off.

set terminal:charheight to 18.

//runpath ("LaunchToOrbit V03.ks",100,0,"NORTH",100,13,60,"RAILS",10,"NOSYNC").
//kuniverse:quicksaveto("DunaAndReturn launch from Kerbin").
//kuniverse:pause().

runpath ("EscapeSOIFromOrbit V01.ks",90,"RAILS").
wait 1.
kuniverse:quicksaveto("DunaAndReturn escape Kerbin").
kuniverse:pause().

runpath ("AdjustOrbitApsides V01.ks","CIRCULARIZE",30,"RAILS").
wait 1.
kuniverse:quicksaveto("DunaAndReturn Kerbol circularization").
kuniverse:pause().

runpath ("PlaneChange V02.ks",0,"Duna","AN",30,"RAILS").
wait 1.
kuniverse:quicksaveto("DunaAndReturn Duna plane change").
kuniverse:pause().

runpath ("HohmannTransfer V02.ks",0,"Duna",30,"RAILS").
wait 1.
kuniverse:quicksaveto("DunaAndReturn Duna transfer").
kuniverse:pause().

runpath ("CaptureOrbit V01.ks",30,"RAILS").
wait 1.
kuniverse:quicksaveto("DunaAndReturn Duna capture").
kuniverse:pause().