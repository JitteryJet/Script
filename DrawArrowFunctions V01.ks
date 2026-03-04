// Name: DrawArrorFunctions
// Author: JitteryJet
// Version: V01
// kOS Version: 1.3.2.0
// KSP Version: 1.11.2
// Description:
//    Functions to draw arrows on the KSP GUI.
//
// Notes:
//    - Functions to draw arrows, usually as a debugging aid or
//      a "sanity check" on some of the dodgy vectors used by
//      KSP.
//
// Todo:
//    -
//
// Update History:
//    29/03/2021 V01  - Created. WIP.
//                    - Added "lazyglobal off"
//                    - Declare these functions GLOBAL to make it
//                      clear they are intended to be global in scope.
@lazyglobal off.
global function DrawSOIRawAxes
  {
// Draw arrows to show the SOI-RAW axes.
// Notes:
//    -
// Todo:
//    -
    parameter ArrowLength is ship:body:radius+1E6.
    parameter ArrowColour is white.

    local X to
      vecdraw
      (
        {return ship:body:position.},
        (v(1,0,0))*Arrowlength,
        ArrowColour,
        "X"
      ).
    set X:wiping to false.
    set X:show to true.

    local Y to
      vecdraw
      (
        {return ship:body:position.},
        (v(0,1,0))*ArrowLength,
        ArrowColour,
        "Y"
      ).
    set Y:wiping to false.
    set Y:show to true.

    local Z to
      vecdraw
      (
        {return ship:body:position.},
        (v(0,0,1))*ArrowLength,
        ArrowColour,
        "Z"
      ).
    set Z:wiping to false.
    set Z:show to true.
  }

global function DrawSAMVector
  {
// Draw the Specific Anglular Momentum pseudovector for an orbit.
// Just think of this as the axis of the orbit if the terminology
// is scary.
// Notes:
//    -
// Todo:
//    -
    parameter SOIPositionVec.
    parameter VelocityVec.
    parameter ArrowLabel to "H".
    parameter ArrowLength to ship:body:radius+1E6.
    parameter ArrowColour to yellow.

    local H to
      vecdraw
      (
        {return ship:body:position.},
        vcrs(SOIPositionVec,VelocityVec):normalized*Arrowlength,
        ArrowColour,
        ArrowLabel
      ).
    set H:wiping to false.
    set H:show to true.
  }

global function DrawEccentricityVector
  {
// Draw the eccentricity vector.
// Notes:
//    - It is the line which points from the centre of the SOI
//      to the periapsis
// Todo:
//    -
    parameter EccentricityVec.
    parameter ArrowLabel to "Ecc".
    parameter ArrowLength to ship:body:radius+1E6.
    parameter ArrowColour to red.
    local ecc to
      vecdraw
      (
        {return ship:body:position.},
        EccentricityVec:normalized*Arrowlength,
        ArrowColour,
        ArrowLabel
      ).
    set Ecc:wiping to false.
    set Ecc:show to true.
  }

global function DrawLineOfNodes
  {
// Draw the ascending node section of the line of nodes.
// Notes:
//    - It is the line which points from the centre of the SOI
//      to the periapsis.
// Todo:
//    -
    parameter ANPositionVector.
    parameter ArrowLabel to "AN".
    parameter ArrowLength to ship:body:radius+1E6.
    parameter ArrowColour to green.
    local AN to
      vecdraw
      (
        {return ship:body:position.},
        ANPositionVector:normalized*Arrowlength,
        ArrowColour,
        ArrowLabel
      ).
    set AN:wiping to false.
    set AN:show to true.
  }