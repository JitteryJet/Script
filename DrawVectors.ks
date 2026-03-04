local lock ShipPositionVec to ship:position-ship:body:position.
local lock ShipVelocityVec to ship:velocity:obt.


DrawSAMVector
  (
    ShipPositionVec,
    ShipVelocityVec
  ).

DrawVelocityVector
  (
    ship:body:obt:velocity:orbit
  ).

DrawQuadrantVector
  (
    ShipPositionVec,
    ShipVelocityVec,
    ship:body:obt:velocity:obt
  ).

wait until false.

local function DrawSAMVector
  {
// Draw the Specific Anglular Momentum pseudovector for an orbit.
// Just think of this as the axis of the orbit if the terminology
// is scary.
// Notes:
//    -
// Todo:
//    -
    parameter PositionVec.
    parameter VelocityVec.
    parameter ArrowLabel to "H".
    parameter ArrowLength to ship:body:radius+1E6.
    parameter ArrowColour to yellow.

    local H to
      vecdraw
      (
        {return ship:body:position.},
        vcrs(PositionVec,VelocityVec):normalized*Arrowlength,
        ArrowColour,
        ArrowLabel
      ).

    set H:wiping to false.
    set H:show to true.
  }

local function DrawVelocityVector
  {
// Draw the velocity vector.
// Notes:
//    -
// Todo:
//    -
    parameter VelocityVec.
    parameter ArrowLabel to "V".
    parameter ArrowLength to ship:body:radius+1E6.
    parameter ArrowColour to green.

    local V to
      vecdraw
      (
        {return ship:body:position.},
        VelocityVec:normalized*Arrowlength,
        ArrowColour,
        ArrowLabel
      ).
      
    set V:wiping to false.
    set V:show to true.
  }

local function DrawQuadrantVector
  {
// Draw the quadrant vector.
// Notes:
//    -
// Todo:
//    -
    parameter PositionVec.
    parameter VelocityVec.
    parameter ZeroPointVec.
    parameter ArrowLabel to "Q".
    parameter ArrowLength to ship:body:radius+1E6.
    parameter ArrowColour to red.

    local Q to
      vecdraw
      (
        {return ship:body:position.},
        vcrs(vcrs(PositionVec,VelocityVec),ZeroPointVec):normalized*Arrowlength,
        ArrowColour,
        ArrowLabel
      ).
      
    set Q:wiping to false.
    set Q:show to true.
  }