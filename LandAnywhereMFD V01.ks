// Name: LandAnywhereMFD
// Author: JitteryJet
// Version: V01
// kOS Version: 1.3.2.0
// KSP Version: 1.12.3
// Description:
//    Multi-function Display (MFD) for the LandAnywhere program.
//
// Notes:
//    - Coded using Delegates.
//    - Current vessel only ie the vessel running the calling program.
//    - It should be possible to call this script from programs other than LandFromOrbit,
//      but it was designed with LandFromOrbit in mind.
//    - The clearscreen and a big enough terminal size are set in the caller, I didn't want to
//      make any assumptions about how the caller might want the terminal set.
//    - The screen can be refreshed as little or as often as possible.
//      The refresh can be done by a trigger, but keep it mind it will use up some of the
//      physics tick.
//    -
//
// Todo:
//    -
//
// Update History:
//    14/02/2022 V01  - Created. WIP. 
//
// MFD Label Abbreviations:
//  Function      MFD Function Name.
//  Vessel Name   Name of this vessel.
//  VSpd          Vertical Speed (m/s).
//  ASL           Height Above Sea Level (km).
//  AGL           Height Above Ground Level (km).
//  StopD         Stopping Distance (km).
//	Ap            Orbit Apoapsis (km).
//	Pe	          Orbit Periapsis (km).
//  Ecc           Orbit Eccentricity.
//	Stat	        Flight Status
//  DeObt         Deorbit Type.
//  LHt           Landing Height (m).
//  LSpd          Landing Speed (m/s).
//	BnIn	        Maneuver Burn In Time (s).
//  BnDu	        Maneuver Burn Duration (s).
//	BnDv	        Maneuver Burn Delta-v (m/s).
//  SDist         Suicide Stopping Distance (m).

@lazyglobal off.

// Expose the delegates.
global LandAnywhereMFD to lexicon
  (
    "DisplayLabels",DisplayLabels@,
    "DisplayRefresh",DisplayRefresh@,
    "DisplayDiagnostic",DisplayDiagnostic@,
    "DisplayManeuver",DisplayManeuver@,
    "DisplayFlightStatus",DisplayFlightStatus@,
    "DisplayError",DisplayError@
  ).

// Variables to keep track of datum line numbers
local VSpdLine to 0.
local ASLLine to 0.
local AGLLine to 0.
local StopDLine to 0.
local ApLine to 0.
local PeLine to 0.
local EccLine to 0.
local Nameline to 0.
local StatLine to 0.
local DeObtLine to 0.
local LHtLine to 0.
local LSpdLine to 0.
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
    parameter DeObt.
    parameter LHt.
    parameter LSpd.

    local line to 0.

//         -123456789-123456789-123456789-123456789-123456789-12345
//         XXXXXX XXXXXXXXXXXXXXXXXX      XXXXXX XXXXXXXXXXXXXXXXXX
    print "                                                        " at (0,line).
    set line to line+1.
    print "                                                        " at (0,line).
    set line to line+1.
    print "Function: Land Anywhere                                 " at (0,line).
    set line to line+1.
    print "Vessel Name:                                            " at (0,line).
    set NameLine to line. set line to line+1.
    print "---------VESSEL----------      --------AUTOPILOT--------" at (0,line).
    set line to line+1.
    print "VSpd:                          Stat:                    " at (0,line).
    set VSpdLine to line. set StatLine to line. set line to line+1.
    print "ASL:                           DeObt:                   " at (0,line).
    set ASLLine to line. set DeobtLine to line. set line to line+1.
    print "AGL:                           LHt:                     " at (0,line).
    set AGLLine to line. set LHtLine to line. set line to line+1.
    print "StopD:                         LSpd:                    " at (0,line).
    set StopDLine to line. set LSpdLine to line. set line to line+1.
    print "----------ORBIT----------                               " at (0,line).
    set line to line+1.
    print "Ap:                                                     " at (0,line).
    set ApLine to line. set line to line+1.
    print "Pe:                                                     " at (0,line).
    set PELine to line. set line to line+1.
    print "Ecc:                                                    " at (0,line).
    set EccLine to line. set line to line+1.
    print "-----ESTIMATED BURN------                               " at (0,line).
    set line to line+1.
    print "BnIn:                                                   " at (0,line).
    set BnInLine to line. set line to line+1.
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

    print VesselName at (13,NameLine).
    print DeObt at (Col2Col,DeObtLine).
    print MFDVal(round(LHt,1)+" m") at (Col2Col,LHtLine).
    print MFDVal(round(LSpd,1)+" m/s") at (Col2Col,LSpdLine).
  }

local function DisplayRefresh
  {
// Refresh the MFD data on the display.
// Notes:
//    - This is to display the datas that keep changing.

    parameter VSpd.
    parameter ASL.
    parameter AGL.
    parameter StopD.
    parameter ap.
    parameter pe.
    parameter ecc.
    parameter BurnStartTime.
    parameter TimeSeconds.

    print MFDVal(round(VSpd,1)+" m/s") at (Col1Col,VSpdLine).
    print MFDVal(round(ASL/1000,3)+" km") at (Col1Col,ASLLine). 
    print MFDVal(round(AGL/1000,3)+" km") at (Col1Col,AGLLine).
    print MFDVal(round(StopD/1000,3)+" km") at (Col1Col,StopDLine).
    print MFDVal(round(ap/1000,3)+" km") at (Col1Col,ApLine). 
    print MFDVal(round(pe/1000,3)+" km") at (Col1Col,PeLine).
    print MFDVal(round(ecc,4)) at (Col1Col,EccLine).

    if BurnStartTime <> 0
      {
        if BurnStartTime >= TimeSeconds
          print MFDVal("T-"+round(abs(TimeSeconds-BurnStartTime),1)+" s") at (Col1Col,BnInLine).
        else
          print MFDVal("T+"+round(TimeSeconds-BurnStartTime,1)+" s") at (Col1Col,BnInLine).
      }
  }

local function DisplayManeuver
  {
// Display the maneuver data.

    parameter BnDu.
    parameter BnDv.

    print MFDVal(round(BnDu,1)+" s") at (Col1Col,BnDuLine).
    print MFDVal(round(BnDv,1)+" m/s") at (Col1Col,BnDvLine).
  }

local function DisplayFlightStatus
  {
// Display the Flight Status data.

    parameter stat.

    print stat:padright(ColSize) at (Col2Col,StatLine).
  }

local function DisplayError
  {
// Display the error info lines.
    parameter ErrorLine1.

    print ErrorLine1:tostring:padright(LineSize) at (0,Error1Line).
  }

local function DisplayDiagnostic
  {
// Display the diagnostic info lines.
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