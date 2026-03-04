// eva. kOS-EVA Mod Boot file.
// When a Kerbal spawns, this boot file is ran.
//wait 0.
//wait until ship:unpacked.
//core:part:getmodule("kOSProcessor"):doevent("Open Terminal").
//runoncepath("Archive:/Kerbal Career Using kOS/CareerEVA1").
//until false
//  {
//    print ship:name.
//    if ship:name = "Kelly Kerman"
//      {
//        core:part:getmodule("kOSProcessor"):doevent("Open Terminal").
//        runoncepath("KellyKermanTest").
//        break.
//      }
//    wait 0.
//  }