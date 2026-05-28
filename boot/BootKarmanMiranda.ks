// Boot script for the "Karman Miranda" sounding rocket.

wait until ship:unpacked.
if ship:status = "PRELAUNCH"
  {
    core:part:getmodule("kOSProcessor"):doevent("Open Terminal").
    runoncepath("archive:/KSP RP-1 kOS Firstplay/LaunchKarmanMiranda").
  }