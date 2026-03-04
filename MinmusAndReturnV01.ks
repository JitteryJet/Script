// Program Title: MinmusAndReturn
// Author: JitteryJet
// Version: V01
// kOS Version: 1.3.2.0
// KSP Version: 1.11.2
// Description:
//  Launch a vessel from Kerbin to Minmus and return.
//
// Notes:
//    - Tuned to work with the Kerbal X vessel.
//      It will probably work with other vessels.
//
// Todo
//    - Complete coding the script.
//
// Update History:
//    27/03/2021 V01  - Created. WIP.
@lazyglobal off.

set terminal:charheight to 18.

runpath ("LaunchToOrbit V03.ks",100,0,"NORTH",100,13,60,"RAILS",10,"NOSYNC").
clearscreen.
wait 5.
runpath ("PlaneChange V02.ks",0,"Mun","AN",90,"RAILS").
clearscreen.
wait 5.
runpath ("HohmannTransfer V01.ks",0,"Mun",90,"RAILS").
clearscreen.
wait 5.
runpath ("CaptureOrbit V01.ks",30,"RAILS").
clearscreen.
wait 5.
runpath ("LandFromOrbit V01.ks",30,"RAILS").
clearscreen.
// Attempt to keep the ship upright if the surface is tilted.
lock steering to ship:up.
wait 10.
runpath ("LaunchToOrbit V03.ks",20,0,"NORTH",0,80,30,"RAILS",10,"NOSYNC").
clearscreen.
wait 5.
runpath ("EscapeSOIFromOrbit V01.ks",30,"RAILS").
clearscreen.
wait 5.
runpath ("AdjustOrbitApsides V01.ks","CIRCULARIZE",30,"RAILS").
clearscreen.
wait 5.
runpath ("PlaneChange V02.ks",0,"","AN",30,"RAILS").
clearscreen.
wait 5.
// Lower the orbit to just inside the atmosphere
// to start the reentry.
runpath ("HohmannTransfer V01.ks",65,"",30,"RAILS").
stage.
// Deploy the parachutes when it is safe.
//WHEN (NOT CHUTESSAFE)
//  THEN
//    {
//      CHUTESSAFE ON.
//      RETURN (NOT CHUTES).
//    }
chutes on.