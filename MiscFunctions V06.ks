// Name: MiscFunctions
// Author: JitteryJet
// Version: V06
// kOS Version: 1.4.0.0
// KSP Version: 1.12.5
// Description:
//    Miscellaneous Functions.
//
// Notes:
//    - Only generic fully parameterised functions.
//    -
// Todo:
//    -
//    -
// Update History:
//    24/07/2020 V01  - Created.
//    26/03/2021 V02  - Added "lazyglobal off"
//                    - Declare these functions GLOBAL to make it
//                      clear they are intended to be global in scope.
//    30/04/2021 V03  - Added function to calculate the intersection point
//                      between a line and a plane.
//    26/04/2021 V04  - Added clamp function.
//    30/04/2023 V05  - Remove name clash with the builtin function called "min".
//                    - Add CalcCot function.
//    06/09/2024 V06  - WIP
//                    - Added DoSafeWait function. 
//                    -
//
@lazyglobal off.

global function NearEqual
  {
// True if two values are equal within a specified margin.
    parameter value1.
    parameter value2.
    parameter margin.

    if value1 >= value2 - margin and value1 <= value2 + margin
      return true.
    else
      return false.
  }

global function WarpToTime
  {
// Warp to a point in time.
// Notes:
//    -
// Todo:
    parameter ToTime.
    parameter mode.

    set kuniverse:timewarp:mode to mode.
    kuniverse:timewarp:warpto(ToTime).
  }

global function CalcLinePlaneIntersection
  {
// Calculate the intersection position between a line and a plane.
// Notes:
//    - Returns the intersection position if there is one.
//    - Returns V(0,0,0) if the line lies on the
//      plane or the line does not intersect the plane. 
//    - The equation is from Wikipedia. It appears to be the
//      common Algebraic Form for vectors.
//    - Example usage is to predict the impact point ahead of a
//      vessel heading towards the surface of a body. The "plane" is defined
//      as the surface directly under vessel, the line is the velocity vector.
//      This ignores the curvature of the body.
//    -
// Todo:
//    -
    parameter LineVec.          // Vector defining the line. 
    parameter PlaneNormalVec.   // Vector defining the normal line to the plane.
    parameter LinePos.          // Position defining the point on the line.
    parameter PlanePos.         // Position defining the point on the plane.

    local denominator to vdot(LineVec,PlaneNormalVec).

    if denominator = 0
      return V(0,0,0).
    else
      return
        (vdot(PlanePos-LinePos,PlaneNormalVec)/denominator)
        *LineVec+LinePos.
  }

global function clamp
  {
// Graphics clamp.
// Notes:
//    -
// Todo:
//    -
    parameter x.
    parameter MinValue.
    parameter MaxValue.

    if x < MinValue
      set x to MinValue.
    else
    if x > MaxValue
      set x to MaxValue.
    return x.
  }

global function CalcCot
  {
// Cotangent function input degrees.

    parameter angle.

//    local cotx to cos(angle)/sin(angle).
    local cotx to 1/tan(angle).

    return cotx. 
  }

  global function DoSafeWait
  {
// A relatively reliable "Wait until a point in time" function
// that handles time warping.
// Notes:
//    - The KSP Time Warp is a "4th Wall" function as far as
//      kOS is concerned. Time Warp runs independently of kOS and can
//      respond to user input. Time Warp is not well synchronised
//      with kOS.
//    - This function tries to allow for various factors that
//      can affect how well kOS and Time Warp run together.
//    -
// Todo
//    - Test, test and test some more.
//    -

    parameter WaitToTStmp.
    parameter WarpTypeCode to "".   // NOWARP,PHYSICS,RAILS.

    if WarpTypeCode = "NOWARP"
      wait until timestamp() > WaitToTStmp.
    else
    if WarpTypeCode = "PHYSICS"
      {
        set kuniverse:timewarp:mode to WarpTypeCode.
        kuniverse:timewarp:warpTo(WaitToTStmp:seconds).
        wait until timestamp() > WaitToTStmp.
      }
    else
    if WarpTypeCode = "RAILS"
      {
// On-rails time warping only runs a limited game simulation,
// the ship is unpacked, some system values become undefined etc.
// The Player can also change the warp rate or stop the time warp completely.
// The "wait until" tries to get the time warp and the kOS script back into
// sync without issues.
        set kuniverse:timewarp:mode to WarpTypeCode.
        kuniverse:timewarp:warpTo(WaitToTStmp:seconds).
        wait until kuniverse:timewarp:warp = 0 and ship:unpacked.

// This "wait until" runs independently of the time warp.
// This wait will still work even if the time warp is modified by
// Player input.
// If the time warp stops early (undershoots) the wait duration will
// still be correct. If the time warp stops late (overshoots) then
// the wait duration will be longer than expected.
        wait until timestamp() > WaitToTStmp.
      }
    else
      print 0/0.  // Unknown WarpType value so terminate the script.
  }