// Name: HohmannTransferMFD
// Author: JitteryJet
// Version: V02
// kOS Version: 1.3.2.0
// KSP Version: 1.12.1
// Description:
//    Multi-function Display (MFD) for the HohmannTransfer program.
//
// Notes:
//    - Coded using Delegates.
//    - Current vessel only ie the vessel running the calling program.
//    - It should be possible to call this script from programs other than HohmannTransfer,
//      but it was designed with HohmannTransfer in mind.
//    - The clearscreen and a big enough terminal size are set in the caller, I didn't want to
//      make any assumptions about how the caller might want the terminal set.
//    - The screen can be refreshed as little or as often as possible.
//      The refresh can be done by a trigger, but keep it mind it will use up some of the
//      physics tick.
//
// Todo:
//    - Test different refresh rates to see which one works the best.
//
// Update History:
//    26/03/2021 V01  - Created.
//    10/08/2021 V02  - Added orbital phase angles.
//                    - Added eccentricity.
//                    - Increased the size of the value columns
//                      to allow for bigger numbers.
//                    - Increased precision of burn delta-v.
//
// MFD Label Abbreviations:
//  Function      MFD Function Name.
//  Vessel Name   Name of this vessel .
//	Ap            Orbit Apoapsis (km).
//	Pe	          Orbit Periapsis (km).
//  Ecc           Orbit Eccentricity.
//	Stat	        Flight Status.
//	BnIn	        Maneuver Burn In Time (s).
//  BnDu	        Maneuver Burn Duration (s).
//	BnDv	        Maneuver Burn Delta-v (m/s).
//  TObt          Name of the target orbital or altitude (km).
//  RAng          Relative angle to target orbital (deg).
//  TAng          Transfer angle (deg).
//
@lazyglobal off.
//{
// Expose the delegates.
global HohmannTransferMFD to lexicon
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
local TObtline to 0.
local RAngLine to 0.
local TAngline to 0.
local StatLine to 0.
local Diag1Line to 0.
local Diag2Line to 0.
local BnInLine to 0.
local BnDuLine to 0.
local BnDvLine to 0.
local Error1Line to 0.
local Col1Col to 7.
local Col2Col to 35.
local ColSize is 15.

local function DisplayLabels
  {
// Display the labels, headings and any data that does not change.
// Calculate the line numbers for each datum.
// Notes:
//    - The two blank lines at the top of the screen allow for the
//      "Program ended" message line and the following cursor line.
//
    parameter VesselName.
    parameter OrbitAltitude.
    parameter TObtName.
    
    local line to 0.

//         -123456789-123456789-123456789-123456789-123456789
//         XXXXXX XXXXXXXXXXXXXXX      XXXXXX XXXXXXXXXXXXXXX
    print "                                                  " at (0,line).
    set line to line+1.
    print "                                                  " at (0,line).
    set line to line+1.
    print "Function: Hohmann Transfer                        " at (0,line).
    set line to line+1.
    print "Vessel Name:                                      " at (0,line).
    set NameLine to line. set line to line+1.
    print "--------VESSEL--------      -------AUTOPILOT------" at (0,line).
    set line to line+1.
    print "Ap:                         TObt:                 " at (0,line).
    set ApLine to line. set TObtline to line. set line to line+1.
    print "Pe:                                               " at (0,line).
    set PeLine to line. set line to line+1.
    print "Ecc:                        Stat:                 " at (0,line).
    set EccLine to line. set StatLine to line. set line to line+1.
    print "RAng:                                             " at (0,line).
    set RAngLine to line. set line to line+1.
    print "TAng:                                             " at (0,line).
    set TAngLine to line. set line to line+1.
    print "---ESTIMATED BURN--                               " at (0,line).
    set line to line+1.
    print "BnIn:                                             " at (0,line).
    set BnInLine to line. set line to line+1.
    print "BnDu:                                             " at (0,line).
    set BnDuLine to line. set line to line+1.
    print "BnDv:                                             " at (0,line).
    Set BnDvLine to line. set line to line+1.
    print "-----ERROR MSG----                                " at (0,line).
    set line to line+1.
    print "                                                  " at (0,line).
    set Error1Line to line. set line to line+1.
    print "---DIAGNOSTICS----                                " at (0,line).
    set line to line+1.
    print "                                                  " at (0,line).
    set Diag1Line to line. set line to line+1.
    print "                                                  " at (0,line).
    set Diag2Line to line. set line to line+1.

    print VesselName at (13,Nameline).
    if TObtName = ""
      print MFDVal(round(OrbitAltitude/1000,3)+" km") at (Col2Col,TObtLine).
    else
      {
        if TObtName:length > ColSize
          print TObtName:substring(0,ColSize) at (Col2Col,TObtline).
        else
          print TObtName at (Col2Col,TObtline).
      }
    
  }

local function DisplayRefresh
  {
// Refresh the MFD data on the display.
// Notes:
//    - This is to display the datas that keep changing.

    parameter Ap.
    parameter Pe.
    parameter Ecc.
    parameter RAng.
    parameter TAng.
    parameter BurnStartTime.
    parameter UTSeconds.

    print MFDVal(round(Ap/1000,3)+" km") at (Col1Col,ApLine). 
    print MFDVal(round(Pe/1000,3)+" km") at (Col1Col,PeLine).
    print MFDVal(round(Ecc,4)) at (Col1Col,EccLine).
    print MFDVal(round(RAng,1)+char(176)) at (Col1Col,RAngLine).
    print MFDVal(round(TAng,1)+char(176)) at (Col1Col,TAngLine).

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

    print (ErrorLine1) at (0,Error1Line).
  }

local function DisplayDiagnostic
  {
// Update the diagnostic info lines.
    parameter DiagLine1.
    parameter DiagLine2.

    print (DiagLine1) at (0,Diag1Line).
    print (DiagLine2) at (0,Diag2Line).
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
