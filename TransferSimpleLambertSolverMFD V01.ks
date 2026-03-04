// Name: TransferSimpleLambertSolverMFD
// Author: JitteryJet
// Version: V01
// kOS Version: 1.3.2.0
// KSP Version: 1.12.3
// Description:
//    Multi-function Display (MFD) for the TransferSimpleLambertSolver program.
//
// Notes:
//    - Coded using Delegates.
//    - The screen is cleared and terminal size are set in the caller, it does not
//      make any assumptions about how the caller might want the terminal set.
//    - The screen can be refreshed as little or as often as possible.
//      The refresh can be done by a trigger, but keep it mind it will use up some of the
//      physics tick.
//
// Todo:
//    -
//
// Update History:
//    15/07/2022 V01  - Created.
//                    - 
//
// MFD Label Abbreviations:
//  Function      MFD Function Name.
//  Ship Name     Name of this ship.
//	Ap            Orbit Apoapsis (km).
//	Pe	          Orbit Periapsis (km).
//  Ecc           Orbit Eccentricity.
//	Stat	        Flight Status.
//  Targ          Name of the target body or ship.
//  SType         Search Type.
//	BnIn	        Maneuver Burn In Time (s).
//  BnDu	        Maneuver Burn Duration (s).
//	BnDv	        Maneuver Burn Delta-v (m/s).
//  DTime         Departure time.
//  TTime         Transfer time.
//  FTTme         Final transfer time after search.
//  FDTIn         Final departure time in after search.
//  FTDv          Final transfer delta-v after search.
//  FSMA          Final Transfer Semi-major Axis after search (km).
//  Step          Search step (s).
//
@lazyglobal off.
//
// Expose the delegates.
global MFDFunctions to lexicon
  (
    "DisplayLabels",DisplayLabels@,
    "DisplayRefresh",DisplayRefresh@,
    "DisplayDiagnostic",DisplayDiagnostic@,
    "DisplayManuever",DisplayManuever@,
    "DisplayFlightStatus",DisplayFlightStatus@,
    "DisplayError",DisplayError@,
    "DisplaySearchResults",DisplaySearchResults@
  ).

local ApLine to 0.
local PeLine to 0.
local EccLine to 0.
local NameLine to 0.
local TargLine to 0.
local STypeLine to 0.
local StepLine to 0.
local DTimeLine to 0.
local TTimeLine to 0.
local FDTInLine to 0.
local FSMALine to 0.
local FTTmeLine to 0.
local FTDvLine to 0.
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
local VeryBigNumber to 3.402823E+38.

local function DisplayLabels
  {
// Display the labels, headings and any data that does not change.
// Calculate the line numbers for each datum.
// Notes:
//    - The two blank lines at the top of the screen allow for the
//      "Program ended" message line and the following cursor line.
//
    parameter MyShipName.
    parameter TargName.
    parameter SearchType.
    
    local line to 0.

//         -123456789-123456789-123456789-123456789-123456789-12345
//         XXXXXX XXXXXXXXXXXXXXXXXX      XXXXXX XXXXXXXXXXXXXXXXXX
    print "                                                        " at (0,line).
    set line to line+1.
    print "                                                        " at (0,line).
    set line to line+1.
    print "Function: Transfer Using Simple Lambert Solver          " at (0,line).
    set line to line+1.
    print "Ship Name:                                              " at (0,line).
    set NameLine to line. set line to line+1.
    print "-----------SHIP----------      --------AUTOPILOT--------" at (0,line).
    set line to line+1.
    print "Ap:                            Stat:                    " at (0,line).
    set ApLine to line. set Statline to line. set line to line+1.
    print "Pe:                            Targ:                    " at (0,line).
    set PeLine to line. set TargLine to line. set line to line+1.
    print "Ecc:                           SType                    " at (0,line).
    set EccLine to line. set STypeLine to line. set line to line+1.
    print "                               ----------SEARCH---------" at (0,line).
    set line to line+1.
    print "                               Step:                    " at (0,line).
    set StepLine to line. set line to line+1.
    print "-----ESTIMATED BURN------      DTime:                   " at (0,line).
    set DTimeLine to line. set line to line+1.
    print "BnIn:                          TTime:                   " at (0,line).
    set BnInLine to line. set TTimeLine to line. set line to line+1.
    print "BnDu:                          -----SEARCH RESULTS------" at (0,line).
    set BnDuLine to line. set line to line+1.
    print "BnDv:                          FDTIn:                   " at (0,line).
    set BnDvLine to line. set FDTInLine to line. set line to line+1.
    print "                               FTTme:                   " at (0,line).
    set FTTmeLine to line. set line to line+1.
    print "                               FSMA:                    " at (0,line).
    set FSMALine to line. set line to line+1.
    print "                               FTDv:                    " at (0,line).
    set FTDvLine to line. set line to line+1.
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

    print MyShipName at (13,Nameline).
    if TargName:length > ColSize
      print TargName:substring(0,ColSize) at (Col2Col,Targline).
    else
      print TargName at (Col2Col,Targline).
    print SearchType at (Col2Col,StypeLine).
  }

local function DisplayRefresh
  {
// Refresh the MFD data on the display.
// Notes:
//    - This is to display the datas that keep changing.

    parameter Ap.
    parameter Pe.
    parameter Ecc.
    parameter Step.
    parameter DTime.
    parameter TTime.
    parameter BurnStartTStmp.
    parameter CurrentTStmp.

    local DTimeFormatted to "Y"+DTime:year+"D"+DTime:day+" "+DTime:clock.

    print MFDVal(round(Ap/1000,3)+" km") at (Col1Col,ApLine). 
    print MFDVal(round(Pe/1000,3)+" km") at (Col1Col,PeLine).
    print MFDVal(round(Ecc,4)) at (Col1Col,EccLine).
    print MFDVal(round(Step,1)+" s") at (Col2Col,StepLine).
    print MFDVal(DTimeFormatted) at (Col2Col,DTimeLine).
    print MFDVal(TTime:full) at (Col2Col,TTimeLine).
    if BurnStartTStmp = timestamp(0)
      print MFDVal("") at (Col1Col,BnInLine).
    else
      {
        if BurnStartTStmp > CurrentTStmp
          print MFDVal("T-"+round(abs((CurrentTSTmp-BurnStartTStmp):seconds),1)+" s") at (Col1Col,BnInLine).
        else
          print MFDVal("T+"+round((CurrentTSTmp-BurnStartTStmp):seconds,1)+" s") at (Col1Col,BnInLine).
      }
  }

local function DisplayManuever
  {
// Update the manuever data.

    parameter BnDu.
    parameter BnDv.

    print MFDVal(round(BnDu,1)+" s") at (Col1Col,BnDuLine).
    print MFDVal(round(BnDv,2)+" m/s") at (Col1Col,BnDvLine).
  }

local function DisplaySearchResults
  {
// Update the search results data.

    parameter FDTin.
    parameter FTTme.
    parameter FSMA.
    parameter FTDV.

    print MFDVal(FDTIn:full) at (Col2Col,FDTInLine).
    print MFDVal(FTTme:full) at (Col2Col,FTTmeLine).
    print MFDVal(round(FTDV,2)+" m/s") at (Col2Col,FTDVLine).

    if FSMA = VeryBigNumber
      print MFDVal("Infinity") at (Col2Col,FSMALine).
    else
      print MFDVal(round(FSMA/1000,3)+" km") at (Col2Col,FSMALine).

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
      set FmtVal to Val:padright(ColSize).
    else
      set FmtVal to Val:padleft(ColSize).

    return FmtVal.
  }