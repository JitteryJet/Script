// Name: LambertSolverFunctions
// Author: JitteryJet
// Version: V03
// kOS Version: 1.5.1.0
// KSP Version: 1.12.5
// Description:
//    Lambert Solver functions.
//
// Notes:
//    - The Lambert Solver algorithm and equations are based mostly on the YouTube video series 
//      "AEE462 Lecture 10 - A Bisection Algorithm for the Solution of Lambert's Equation"
//      by M Peet, YouTube channel "Cybernetic Systems and Controls".
//    - Handles "Short Way" and "Long Way" single-revolution elliptical orbits.
//    - Abbreviations used in the orbital calculations (they are reasonably common):
//        a is the semi-major axis.
//        e is eccentricity.
//        E is eccentric anomaly.
//        F is hyperbolic eccentric anomaly.
//        M is mean anomaly.
//        mu is Standard Gravitational Parameter. 
//        nu is true anomaly.
//        r is radius of an orbit.
//        SOE is Specific Orbital Energy.
//        t is time.
//        v is speed (or velocity if a vector).
//    -
//
// Todo:
//    -
//
// Update History:
//    30/05/2023 V01  - Created.
//    01/12/2023 V02  - Added "Long Way" transfer orbits.
//    25/03/2026 V03  - WIP. Added "Long Way" adjustment to
//                      CalcTransferArrVelLambertVec.
//                    - Changed MiscFunctions V05 to V06.
//                    -
//
@lazyglobal off.
// Load in functions from the library.
runoncepath("MiscFunctions V06").

// Log file for debugging.
local LogFilename to kuniverse:realtime:tostring+".txt".

global function CalcTransferTimeLambert
  {
// Calculate the transfer time (TOF).
// Notes:
//    - Uses the modern Lagrange form of Lambert's Equation.
//    - The code is written as a series of steps to make it
//      easier to understand and debug.
//    - 
// Todo:
//    -
    parameter r1.             // Orbit radius at Point1.
    parameter r2.             // Orbit radius at Point2.
    parameter c.              // Chord Point1-Point2.
    parameter a.              // Semi-major axis.
    parameter mu.             // Standard Gravitational Parameter of central body.
    parameter TransferAng.    // Angle to use between Point1 and Point2 - there are two.
    parameter ShortWayOrbit.  // True - Short Way orbit. False - Long Way orbit.

// Semi-perimeter.
    local s to (r1+r2+c)/2.

    local AlphaDeg to 0.0.      // Alpha term in equation.
    local AlphaRad to 0.0.
    local BetaDeg to 0.0.       // Beta term in equation.
    local BetaRad to 0.0.
    local tTransfer to 0.0.

// Temporary fix to get around the value passed to arcsin going
// out of range. The reason is unknown.
//    if sqrt(s/(2*a)) > 1
//      set AlphaDeg to 2*arcsin(1).
//    else

// Set the alpha term of the equation.
// The equation has "short way" and "long way" solutions.
    set AlphaDeg to 2*arcsin(sqrt(s/(2*a))).
    if not ShortWayOrbit
      set AlphaDeg to 360-AlphaDeg.
    set AlphaRad to AlphaDeg*constant:DegToRad.

// Set the beta term of the equation.
// The equation has angle > pi and angle < pi solutions.
    set BetaDeg to 2*arcsin(sqrt((s-c)/(2*a))).
    if TransferAng > 180
      set BetaDeg to -BetaDeg.
    set BetaRad to BetaDeg*constant:DegToRad.

// Calculate the transfer time.
    set tTransfer to sqrt(a^3/mu)*(AlphaRad-sin(AlphaDeg)-(BetaRad-sin(BetaDeg))).
    return timespan(0,0,0,0,tTransfer).
  }

global function CalcSMALambert
  {
// Calculate the semi-major axis.
// Notes:
//    - Uses the Bisection algorithm.
//    - No check is done to see if a solution exists.
//    - 
// Todo:
//    - Try to optimise the algorithm, it appears slow.
//    - Add checks to ensure a solution exists.
//    -     
    parameter t.              // Transfer time (TOF) from Point1 to Point2.
    parameter r1.             // Orbit radius at Point1.
    parameter r2.             // Orbit radius at Point2.
    parameter c.              // Chord Point1-Point2.
    parameter mu.             // Standard Gravitational Parameter of central body.
    parameter TransferAng.    // Angle between Point1 and Point2.

// Bisection Algorithm stopping criteria.
    local TolerancePct to 0.1.
    local tToleranceTSpan to t*TolerancePct/100.

    local a to 0.0.           // Semi-major axis (SMA).
    local s to                // Semi-perimeter.
      (r1+r2+c)/2.
    local amin to 0.0.        // Bisection minimum a.
    local amax to 0.0.        // Bisection maximum a.
    local aMinSOETrans to     // SMA that gives the minimum Specific Orbital Energy
      (r1+r2+c)/4.            // for the possible transfer orbits.

    local finished to false.
    local tcalc to 0.

    local ShortWayOrbit to
      t < CalcTransferTimeLambert(r1,r2,c,aMinSOETrans,mu,TransferAng,true).

// Initial guess of SMA range to search.
    set amin to s/2.
    set amax to 2*s.

// Adjust initial amax guess if it isn't high enough.
    set tcalc to CalcTransferTimeLambert(r1,r2,c,amax,mu,TransferAng,ShortWayOrbit).
    if ShortWayOrbit
      {
        until tcalc < t
          {
            set amax to 2*amax.
            set tcalc to CalcTransferTimeLambert(r1,r2,c,amax,mu,TransferAng,true).
          }
      }
    else
      {
        until tcalc > t
          {
            set amax to 2*amax.
            set tcalc to CalcTransferTimeLambert(r1,r2,c,amax,mu,TransferAng,false).
          }
      }

// Find the SMA.
    until finished
      {
        set a to (amin+amax)/2.
        set tcalc to CalcTransferTimeLambert(r1,r2,c,a,mu,TransferAng,ShortWayOrbit).
        set finished to NearEqual(t:seconds,tcalc:seconds,ttoleranceTSpan:seconds).
        if finished
          break.
        if ShortWayOrbit
          {
            if tcalc > t
              set amin to a.
            else
              set amax to a.
          }
        else
          {
            if tcalc > t
              set amax to a.
            else
              set amin to a.
          }
      }
    return a.
  }

global function CalcTransferDepVelLambertVec
  {
// Calculate the velocity of the transfer orbit at
// the departure point.
// Notes:
//    - Uses the modern Lagrange form of Lambert's Equation.
//    - The code is written as a series of steps to make it
//      easier to understand and debug.
// Todo:
//    - 
    parameter r1Vec.                // Departure point position vector.
    parameter r2Vec.                // Arrival point position vector.
    parameter a.                    // Semi-major axis.
    parameter mu.                   // Standard Gravitational Parameter.
    parameter TransAng.             // Angle to use between Point1 and Point2 - there are two.
    parameter ShortWayOrbit.        // True - Short Way orbit. False - Long Way orbit.

// Cord vector.
    local cVec to r2Vec-r1Vec.

// Cord.
    local c to cVec:mag.

// Semi-perimeter.
    local s to (r1Vec:mag+r2Vec:mag+c)/2.

    local vTransferVec to v(0,0,0).

    local AlphaDeg to 0.
    local BetaDeg to 0.

// Temporary fix to get around the value passed to arcsin going
// out of range. The reason is unknown.
//    if sqrt(s/(2*a)) > 1
//      set AlphaDeg to 2*arcsin(1).
//    else
    set AlphaDeg to 2*arcsin(sqrt(s/(2*a))).

    if TransAng < 180
      set BetaDeg to 2*arcsin(sqrt((s-c)/(2*a))).
    else
      set BetaDeg to -2*arcsin(sqrt((s-c)/(2*a))).

    if not ShortWayOrbit
      set AlphaDeg to 360-AlphaDeg.

    local ACap to sqrt(mu/(4*a))*CalcCot(AlphaDeg/2).
    local BCap to sqrt(mu/(4*a))*CalcCot(BetaDeg/2).

    set vTransferVec to (BCap+ACap)*cVec:normalized+(BCap-ACap)*r1Vec:normalized.

    return vTransferVec.
  }

global function CalcTransferArrVelLambertVec
  {
// Calculate the velocity of the transfer orbit at
// the arrival point.
// Notes:
//    - Uses the modern Lagrange form of Lambert's Equation.
//    - The code is written as a series of steps to make it
//      easier to understand and debug.
//    - 
// Todo:
//    - 
//    -
    parameter r1Vec.                // Departure point position vector.
    parameter r2Vec.                // Arrival point position vector.
    parameter a.                    // Semi-major axis.
    parameter mu.                   // Standard Gravitational Parameter.
    parameter TransferAng.          // Angle between Point1 and Point2.
    parameter ShortWayOrbit.        // True - Short Way orbit. False - Long Way orbit.
//
// Cord vector.
    local cVec to r2Vec-r1Vec.

// Cord.
    local c to cVec:mag.

// Semi-perimeter.
    local s to (r1Vec:mag+r2Vec:mag+c)/2.

// The same alpha and beta parameters used in
// Lambert's Equation.
    local AlphaDeg to 2*arcsin(sqrt(s/(2*a))).
    local BetaDeg to 0.
    if TransferAng < 180
      set BetaDeg to 2*arcsin(sqrt((s-c)/(2*a))).
    else
      set BetaDeg to -2*arcsin(sqrt((s-c)/(2*a))).

    if not ShortWayOrbit
      set AlphaDeg to 360-AlphaDeg.

// A and B are also parameters (I guess...).
    local ACap to sqrt(mu/(4*a))*CalcCot(AlphaDeg/2).
    local BCap to sqrt(mu/(4*a))*CalcCot(BetaDeg/2).

    local vTransferVec to
      (BCap+ACap)*cVec:normalized-(BCap-ACap)*r2Vec:normalized.

    return vTransferVec.
  }

global function CalcParabolicTransferTimeLambert
  {
// Calculate the parabolic transfer time.
// Notes:
//    - The parabolic solution defines the minimum transfer
//      time for the transfer orbit to be elliptical.
//      Transfer times less than this mean the transfer
//      orbit is hyperbolic.
//    - Another way of looking at it is a parabolic
//      solution has an SMA value that approaches infinity.
//      Solutions close to the parabolic solution will
//      also have large SMA values.
//    -
// Todo:
//    -

    parameter r1.       // Orbit radius at Point1.
    parameter r2.       // Orbit radius at Point2.
    parameter c.        // Chord Point1-Point2.
    parameter mu.       // Standard Gravitational Parameter of central body.
    parameter TransAng. // Angle between Point1 and Point2.

// Semi-perimeter.
    local s to (r1+r2+c)/2.

    local sign to 1.

    if TransAng >= 180
      set sign to -sign.

    local tparabolic to
      (sqrt(2)/3)*sqrt(s^3/mu)*(1-sign*((s-c)/s)^1.5).

    return timespan(0,0,0,0,tparabolic).
  }
