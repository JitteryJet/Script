// Program Title: EveAndReturn
// Author: JitteryJet
// Version: V01
// kOS Version: 1.3.2.0
// KSP Version: 1.11.2
// Description:
//  Launch a vessel from Kerbin to Eve and return.
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
//    31/03/2021 V01  - Created. WIP.
//
@lazyglobal off.

set terminal:charheight to 18.

//runpath ("LaunchToOrbit V03.ks",100,0,"NORTH",100,13,60,"RAILS",10,"NOSYNC").
//kuniverse:quicksaveto("EveAndReturn launch from Kerbin").
//kuniverse:pause().

runpath ("EscapeSOIFromOrbit V01.ks",90,"RAILS").
wait 5.
kuniverse:quicksaveto("EveAndReturn escape Kerbin").
kuniverse:pause().
//print 0/0.

runpath ("AdjustOrbitApsides V01.ks","CIRCULARIZE",30,"RAILS").
wait 1.
kuniverse:quicksaveto("EveAndReturn Kerbol circularization").
kuniverse:pause().

runpath ("PlaneChange V02.ks",0,"Eve","AN",30,"RAILS").
wait 1.
kuniverse:quicksaveto("EveAndReturn Eve plane change").
kuniverse:pause().

runpath ("HohmannTransfer V02.ks",0,"Eve",30,"RAILS").
wait 1.
kuniverse:quicksaveto("EveAndReturn Eve transfer").
kuniverse:pause().

runpath ("CaptureOrbit V01.ks",30,"RAILS").
wait 1.
kuniverse:quicksaveto("EveAndReturn Eve capture").
kuniverse:pause().

runpath ("AdjustOrbitApsides V01.ks","CIRCULARIZE",30,"RAILS").
wait 1.
kuniverse:quicksaveto("EveAndReturn 1st circularization").
kuniverse:pause().

runpath ("HohmannTransfer V02.ks",110,"",30,"RAILS").
wait 1.
kuniverse:quicksaveto("EveAndReturn Eve low orbit").
kuniverse:pause().