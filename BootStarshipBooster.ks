// Ensure that the vessel has been unpacked.
wait until ship:unpacked.

core:part:getmodule("kOSProcessor"):doevent("Open Terminal").

// Stage again to activate the current stage correctly.
// I do not know if this is a KSP bug or an oddity caused
// by the fact that a booster becomes a "new" vessel
// after stage separation from the Starship vessel.
stage.
wait until stage:ready.

// Run the booster landing script.
runoncepath("LandStarshipBoosterTest").