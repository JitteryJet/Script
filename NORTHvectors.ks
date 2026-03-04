// Display the ship NORTH direction vectors.

clearVecDraws().

SET NorthFore TO VECDRAW(
  V(0,0,0),
  {return(ship:north:forevector*50).},
  green,
  "Nth Fore",
  1,
  TRUE,
  0.2,
  TRUE,
  TRUE
).

SET NorthTop TO VECDRAW(
  V(0,0,0),
  {return(ship:north:topvector*50).},
  yellow,
  "Nth Top",
  1,
  TRUE,
  0.2,
  TRUE,
  TRUE
).

SET NorthStar TO VECDRAW(
  V(0,0,0),
  {return(ship:north:starvector*50).},
  white,
  "Nth Star",
  1,
  TRUE,
  0.2,
  TRUE,
  TRUE
).

wait until false.