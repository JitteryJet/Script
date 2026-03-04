// Name: PlanetTransferHillClimbingMFD
// Author: JitteryJet
// Version: V02
// kOS Version: 1.3.2.0
// KSP Version: 1.12.3
// Description:
//    Multi-function Display (MFD) for the PlanetTransferHillClimbing program.
//
// Notes:
//    - Coded using Delegates.
//    - Current vessel only ie the vessel running the calling program.
//    - It should be possible to call this script from programs other than PlanetTransfer,
//      but it was designed with PlanetTransfer in mind.
//    - The clearscreen and a big enough terminal size are set in the caller, it does not
//      make any assumptions about how the caller might want the terminal set.
//    - The screen can be refreshed as little or as often as possible.
//      The refresh can be done by a trigger, but keep it mind it will use up some of the
//      physics tick.
//
// Todo:
//    -
//
// Update History:
//    06/01/2022 V01  - Created.
//    11/03/2022 V02  - WIP.
//                    - Move Ejection angle to column 2.
//                    - 
//
// MFD Label Abbreviations:
//  Function      MFD Function Name.
//  Vessel Name   Name of this vessel.
//	Ap            Orbit Apoapsis (km).
//	Pe	          Orbit Periapsis (km).
//  Ecc           Orbit Eccentricity.
//	Stat	        Flight Status.
//	BnIn	        Maneuver Burn In Time (s).
//  BnDu	        Maneuver Burn Duration (s).
//	BnDv	        Maneuver Burn Delta-v (m/s).
//  Targ          Name of the target planet,moon or vessel.
//  EAng          Ejection Angle (deg).
//  Bfore         Before search score (km).
//  Best          Best search score (km).
//  Step          Search step (s).
//
@lazyglobal off.
//
// Expose the delegates.
global PlanetTransferHillClimbingMFD to lexicon
  (
    "DisplayLabels",DisplayLabels@,
    "DisplayRefresh",DisplayRefresh@,
    "DisplayDiagnostic",DisplayDiagnostic@,
    "DisplayManuever",DisplayManuever@,
    "DisplayFlightStatus",DisplayFlightStatus@,
    "DisplayError",DisplayError@
  ).

// Variables to keep track of datum line numbers 
local ApLine to 0.
local PeLine to 0.
local EccLine to 0.
local Nameline to 0.
local Targline to 0.
local StepLine to 0.
local BforeLine to 0.
local BestLine to 0.
local EAngline to 0.
local StatLine to 0.
local Diag1Line to 0.
local Diag2Line to 0.
local BnInLine to 0.
local BnDuLine to 0.
local BnDvLine to 0.
local Error1Line to 0.
local Col1Col to 7.
local Col2Col to 38.
local ColSize is 18.
local LineSize is 56.

local function DisplayLabels
  {
// Display the labels, headings and any data that does not change.
// Calculate the line numbers for each datum.
// Notes:
//    - The two blank lines at the top of the screen allow for the
//      "Program ended" message line and the following cursor line.
//
    parameter VesselName.
    parameter TargName.
    
    local line to 0.

//         -123456789-123456789-123456789-123456789-123456789-12345
//         XXXXXX XXXXXXXXXXXXXXXXXX      XXXXXX XXXXXXXXXXXXXXXXXX
    print "                                                        " at (0,line).
    set line to line+1.
    print "                                                        " at (0,line).
    set line to line+1.
    print "Function: Planetary Transfer Using Hill Climbing        " at (0,line).
    set line to line+1.
    print "Vessel Name:                                            " at (0,line).
    set NameLine to line. set line to line+1.
    print "----------VESSEL---------      --------AUTOPILOT--------" at (0,line).
    set line to line+1.
    print "Ap:                            Stat:                    " at (0,line).
    set ApLine to line. set Statline to line. set line to line+1.
    print "Pe:                            Targ:                    " at (0,line).
    set PeLine to line. set TargLine to line. set line to line+1.
    print "Ecc:                           EAng:                    " at (0,line).
    set EccLine to line.  set EAngLine to line. set line to line+1.
    print "                               ----------SEARCH---------" at (0,line).
    set line to line+1.
    print "                               Step:                    " at (0,line).
    set StepLine to line. set line to line+1.
    print "-----ESTIMATED BURN------      Bfore:                   " at (0,line).
    set BforeLine to line. set line to line+1.
    print "BnIn:                          Best:                    " at (0,line).
    set BnInLine to line. set BestLine to line. set line to line+1.
    print "BnDu:                                                   " at (0,line).
    set BnDuLine to line. set line to line+1.
    print "BnDv:                                                   " at (0,line).
    Set BnDvLine to line. set line to line+1.
    print "--------ERROR MSG--------                               " at (0,line).
    set line to line+1.
    print "                                                        " at (0,line).
    set Error1Line to line. set line to line+1.
    print "-------DIAGNOSTICS-------                               " at (0,line).
    set line to line+1.
    print "                                                        " at (0,line).
    set Diag1Line to line. set line to line+1.
    print "                                                        " at (0,line).
    set Diag2Line to line. set line to line+1.

    print VesselName at (13,Nameline).
    if TargName:length > ColSize
      print TargName:substring(0,ColSize) at (Col2Col,Targline).
    else
      print TargName at (Col2Col,Targline).
  }

local function DisplayRefresh
  {
// Refresh the MFD data on the display.
// Notes:
//    - This is to display the datas that keep changing.

    parameter Ap.
    parameter Pe.
    parameter Ecc.
    parameter EAng.
    parameter Step.
    parameter BeforeScore.
    parameter BestScore.
    parameter BurnStartTime.
    parameter UTSeconds.

    print MFDVal(round(Ap/1000,3)+" km") at (Col1Col,ApLine). 
    print MFDVal(round(Pe/1000,3)+" km") at (Col1Col,PeLine).
    print MFDVal(round(Ecc,4)) at (Col1Col,EccLine).
    print MFDVal(round(EAng,1)+char(176)) at (Col2Col,EAngLine).
    print MFDVal(round(Step,1)+" s") at (Col2Col,StepLine).
    print MFDVal(round(BeforeScore/1000,3)+" km") at (Col2Col,BforeLine).
    print MFDVal(round(BestScore/1000,3)+" km") at (Col2Col,BestLine).

    if BurnStartTime <> 0
      {
        if BurnStartTime >= UTSeconds
          print MFDVal("T-"+round(abs(UTSeconds-BurnStartTime),1)+" s") at (Col1Col,BnInLine).
        else
          print MFDVal("T+"+round(UTSeconds-BurnStartTime,1)+" s") at (Col1Col,BnInLine).
      }
  }

local function DisplayManuever
  {
// Update the manuever data.

    parameter BnDu.
    parameter BnDv.

    print MFDVal(round(BnDu,1)+" s") at (7,BnDuLine).
    print MFDVal(round(BnDv,2)+" m/s") at (7,BnDvLine).
  }

local function DisplayFlightStatus
  {
// Update the Flight Status data.

    parameter stat.

    print stat:padright(ColSize) at (Col2Col,StatLine).
  }

local function DisplayError
  {
// Update the error info lines.
    parameter ErrorLine1.

    print ErrorLine1:tostring:padright(LineSize) at (0,Error1Line).
  }

local function DisplayDiagnostic
  {
// Update the diagnostic info lines.
    parameter DiagLine1.
    parameter DiagLine2.

    print DiagLine1:tostring:padright(LineSize) at (0,Diag1Line).
    print DiagLine2:tostring:padright(LineSize) at (0,Diag2Line).
  }

local function MFDVal
  {
// Format the Multi-function Display value.
// Pad the value from the left with spaces to right-align it.
// If the value is too large, truncate it from the left.
    parameter Val is "".

    local FmtVal is "".

    if Val:istype("Scalar")
      set Val to Val:tostring().

    if Val:length >= ColSize
//        set FmtVal to Val:substring(Val:length-ColSize,ColSize).
      set FmtVal to Val:padright(ColSize).
    else
      set FmtVal to Val:padleft(ColSize).

    return FmtVal.
  }