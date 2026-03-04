// Name: BurnFunctions
// Author: JitteryJet
// Version: V03
// kOS Version: 1.3.2.0
// KSP Version: 1.11.2
// Description:
//    Functions to execute burns.
//
// Notes:
//    -
//
// Todo:
//    -
//
// Update History:
//    24/07/2020 V01  - Created.
//    31/03/2021 V02  - Fixed errors caused by orbital transitions
//                      eg an encounter with a body.
//                    - Added "lazyglobal off"
//                    - Declare these functions GLOBAL to make it
//                      clear they are intended to be global in scope.
//    31/03/2021 V03  - Started again as the methods used to
//                      duplicate the functions of maneuver nodes
//                      by using velocity vectors were unreliable.  
//
@lazyGlobal off.
global function OrbitalBurn
  {
// Burn to apply a velocity change to the orbit of the current vessel.
// Notes:
//    - This function assumes the calculated burn duration is accurate.
//    - This function will prduce unpredictable results if the vessel is staged
//      during the burn - staging during a burn should be avoided anyway.
//    - These functions are unlikely to produce results as good as
//      maneuver nodes.
// Todo:
//    - Consider increasing the one-second ramp down to a longer period
//      for more precise burns.       
//      

    parameter DeltavVec.      // Velocity change of the maneuver.
    parameter BurnDuration.   // Duration of the burn (s). 

// The burn has to go for an additional 0.5 seconds for a 1 second throttle ramp down.
    local BurnEnd to time:seconds+BurnDuration+0.5.
    local tset to 0.
    lock throttle to tset.
    lock steering to lookdirup(DeltavVec,ship:facing:topvector).
    
    until time:seconds > BurnEnd
      {
        set tset to min(BurnEnd-time:seconds,1).
        wait 0.
      }
    unlock throttle.
    unlock steering.
    wait 0.
  }