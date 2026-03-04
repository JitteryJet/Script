// Name: Delta-vFunctions
// Author: JitteryJet
// Version: V05
// kOS Version: 1.5.1.0
// KSP Version: 1.12.5
// Description:
//    Functions to calculate values related to Delta-v.
//
// Notes:
//    -
//
// Todo:
//    -
//
// Update History:
//    24/07/2020 V01  - Created.
//    26/03/2021 V02  - Fixed up AN/DN switch issue.
//                    - Added Hohmann Transfer calculations.
//                    - Added "lazyglobal off"
//                    - Declare these functions GLOBAL to make it
//                      clear they are intended to be global in scope.
//    10/08/2021 V03  - Function name changes.
//    01/12/2023 V04  - Fix up error in ISP calculations for multiple engines.
//                    - Added atmospheric pressure to ISP calcs.
//                    - Fix up error where DeltavEstBurnTime would crash
//                      with a divide by zero error if the fuel runs out.
//    02/01/2026 V05  - WIP
//                    - Attempted to fix strange errors in ISP calcs.
//                      Sometimes the ISP returned is zero. It appears to
//                      be related to staging.
//                    - Added Elliptical Transfer Orbit DeltaV calculation.
//                    -
@lazyglobal off.

global function DeltavEstBurnTime
  {
// Calculate the estimated burn time required to give a
// change in velocity.
// Notes:
//    - The equation allows for changes in mass as fuel is burnt.
//      Refer to the "Ideal Rocket Equation".
//    - The estimate assumes that thrust and ISP remain constant
//      during the burn.
//    -
// Todo:
//    -
    parameter Deltav.
    parameter MassInitial.  // In tonnes.
    parameter thrust.       // In kilonewtons.
    parameter ISP.

    //print Deltav.
    //print MassInitial.
    //print thrust.
    //print isp.
    //kuniverse:pause().

    local EffectiveExhaustVelocity to ISP*constant:g0.
    local MassFinal to MassInitial*constant:e^(-Deltav/EffectiveExhaustVelocity).
    local MassFuel to MassInitial-MassFinal.
    local FuelFlowRate to thrust/EffectiveExhaustVelocity.

    if thrust = 0
      return 0.
    else
      return MassFuel/FuelFlowRate.
  }

global function ISPVesselStage
  {
// Calculate the ISP of the current stage of the vessel.
// Notes:
//    - Lots of assumptions.
//    - Assumes all engines on a stage have the same ISP.
//      The code is designed to stop if they are different.
//    - Ignore the pressure parameter, it is wrong.
//    -
// Todo:
//    - Find out how to calculate the ISP correctly for
//      dissimilar engines.
//    - Fix up the pressure parameter.
//    -

    parameter pressure. // 0 for vacuum, 1 for Kerbin sea level.

    local ISP is 0.
    local englist is 0.
    set englist to ship:engines.
    for eng in englist
      {
        if eng:stage = ship:stagenum
          {
            if ISP = 0
              set ISP to eng:isp.
            else
              {
//                if eng:ISP <> ISP
// Failsafe: Throw an error if any of the ISPs are not the same.
//                  print 0/0.
              }
          }
      }
    return ISP.
  }

global function CalcPlaneChangeDeltavVec
  {
// Calculate the direction and magnitude of the delta-v required
// for a orbital plane change.
// Notes:
//    - Uses the "isosceles triangle" method of calculating the Delta-v.
//      This method changes the orbit inclination without
//      changing any other parts of the orbit (eg without changing
//      orbit eccentricity etc). 
//    -
// Todo:
//    - Test for retrograde orbits etc.
//    -

    parameter PositionVec.
    parameter VelocityVec.
    parameter InclinationChange.
    parameter NodeName.

    local DeltavVec to 0.

    local NormalVec to vcrs(PositionVec,VelocityVec):normalized.

    if NodeName = "AN"
      set DeltavVec to
        -NormalVec*VelocityVec:mag*sin(InclinationChange)
        -VelocityVec*(1-cos(InclinationChange)).
    else
    if NodeName = "DN"
      set DeltavVec to
        NormalVec*VelocityVec:mag*sin(InclinationChange)
        -VelocityVec*(1-cos(InclinationChange)).
    else
      print 0/0.

    return DeltavVec.
  }

global function CalcHohmannTransferDeltav
  {
// Calculate the delta-v required for a Hohmann Transfer.
// Notes:
//    - 
// Todo:
//    -

    parameter r1.  // Radius of the initital orbit.
    parameter r2.  // Radius of the final orbit.
    parameter mu.  // The Gravitational Parameter of the central body.

    local deltav to sqrt(mu/r1) * (sqrt(2 * r2/(r1 + r2)) - 1).

    return deltav.
  }

global function CalcHohmannCircularizationDeltav
  {
// Calculate the delta-v required for the circularization
// after a Hohmann Transfer.
// Notes:
//    - 
// Todo:
//    -

    parameter r1.  // Radius of the initital orbit.
    parameter r2.  // Radius of the final orbit.
    parameter mu.  // The Gravitational Parameter of the central body.

    local deltav to sqrt(mu/r2) * (1 - sqrt(2 * r1/(r1 + r2))).

    return deltav.
  }

global function CalcChangeEllipticalOrbitDeltaV
  {
// Calculate the delta-v required to change the orbit
// of an orbital to another orbit.
// Notes: 
//    - Refer to the "Vis-viva" equation.
//    - An "orbital" is a vessel or body in an orbit.
//    - The orbit and new orbit are elliptical,
//      coplanar and share the same line of apsis.
//      In practice the change to the orbit can
//      only be done at the periapsis or apoapsis.
//    - Delta-v is really a speed.

    parameter OrbitalSpeed.
    parameter OrbitalRadius.
    parameter NewSemiMajorAxis.
    parameter mu.

    local DeltaV to 0.0.
    local NewOrbitalSpeed to 0.0.
    
    set NewOrbitalSpeed to
      sqrt(mu*(2/OrbitalRadius-1/NewSemiMajorAxis)).
    set DeltaV to abs(NewOrbitalSpeed-OrbitalSpeed).
    return DeltaV.
  }