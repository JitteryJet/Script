// Display the ship UP direction vectors.

clearVecDraws().

SET UPFore TO VECDRAW(
  V(0,0,0),
  {return(ship:up:forevector*50).},
  green,
  "UP Fore",
  1,
  TRUE,
  0.2,
  TRUE,
  TRUE
).

SET UPTop TO VECDRAW(
  V(0,0,0),
  {return(ship:up:topvector*50).},
  yellow,
  "UP Top",
  1,
  TRUE,
  0.2,
  TRUE,
  TRUE
).

SET UPStar TO VECDRAW(
  V(0,0,0),
  {return(ship:up:starvector*50).},
  white,
  "UP Star",
  1,
  TRUE,
  0.2,
  TRUE,
  TRUE
).

wait until false.