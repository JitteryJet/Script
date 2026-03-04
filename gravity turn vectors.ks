// Draw the gravity turn vectors for the vessel.

SET ForwardArrow TO VECDRAW(
  V(0,0,0),
  {return(ship:facing:forevector*10).},
  green,
  "Forward",
  1,
  TRUE,
  0.2,
  TRUE,
  TRUE
).

SET SurfaceVelocityArrow TO VECDRAW(
  V(0,0,0),
  {return(ship:srfprograde:forevector*10).},
  yellow,
  "Air Velocity",
  1,
  TRUE,
  0.2,
  TRUE,
  TRUE
).

SET GravityArrow TO VECDRAW(
  V(0,0,0),
  {return(ship:sensors:grav).},
  white,
  "Gravity",
  1,
  TRUE,
  0.2,
  TRUE,
  TRUE
).

SET AccelerationArrow TO VECDRAW(
  V(0,0,0),
  {return(ship:sensors:acc).},
  red,
  "Acceleration",
  1,
  TRUE,
  0.2,
  TRUE,
  TRUE
).

wait until false.