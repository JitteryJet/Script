// Place this file in your archive and call it "boot/<file name>.ks".
wait until ship:unpacked.
CORE:PART:GETMODULE("kOSProcessor"):DOEVENT("Open Terminal").
runoncepath("LaunchFalconHeavyTest").