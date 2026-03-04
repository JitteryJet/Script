//ship:partsdubbedpattern("kerbalEVA")[0]:getmodule("kerbalEVA"):doevent("leave seat").
//  addons:eva:goeva(ship:crew[0]).
local pm to ship:modulesnamed("kerbalEVA").
print pm.
wait 0.
kuniverse:debuglog("Before leave seat event ran.").
pm[0]:doevent("leave seat").
kuniverse:debuglog("After leave seat event ran.").
