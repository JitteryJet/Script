// Name: StarshipAutopilotMFD
// Author: JitteryJet
// Version: V02
// kOS Version: 1.3.2.0
// KSP Version: 1.11.2
// Description:
//    Multi-function Display (MFD) for the StarshipAutopilot program.
//
//Notes:
//    - Coded using Delegates.
//    - Current vessel only ie the vessel running the calling program.
//    - It should be possible to call this script from programs other than StarshipSimulator,
//      but it was designed with StarshipSimulator in mind.
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
//    21/04/2021 V01  - Created.
//    30/04/2021 V02  - Fix up the padding of the diagnotic lines
//                      and the error lines.
//                    - Added distance to target datums.
//                    - Added stopping distance.
//
// MFD Label Abbreviations:
//  Function      MFD Function Name.
//  Vessel Name   Name of this vessel.
//  VSpd          Vertical Speed (m/s).
//  TVSpd         Target Vertical Speed (m/s).
//  ASL           Height Above Sea Level (km).
//  AGL           Height Above Ground Level (km).
//  DTT           Distance to Target (km).
//  HDTT          Horizontal Distance to Target (km).
//  STOPD         Stopping Distance (km)
//	Ap            Orbit Apoapsis (km).
//	Pe	          Orbit Periapsis (km).
//  Ecc           Orbit Eccentricity.
//	Stat	        Flight Status.
//	BnIn	        Maneuver Burn In Time (s).
//  BnDu	        Maneuver Burn Duration (s).
//	BnDv	        Maneuver Burn Delta-v (m/s).
//
@lazyglobal off.
// Expose the delegates.
global StarshipAutopilotMFD to lexicon
  (
    "DisplayLabels",DisplayLabels@,
    "DisplayRefresh",DisplayRefresh@,
    "DisplayDiagnostic",DisplayDiagnostic@,
    "DisplayManeuver",DisplayManeuver@,
    "DisplayFlightStatus",DisplayFlightStatus@,
    "DisplayError",DisplayError@
  ).

// Variables to keep track of datum line numbers.
local VSpdLine to 0.
local TVSpdLine to 0. 
local ASLLine to 0.
local AGLLine to 0.
local DTTLine to 0.
local HDTTLine to 0.
local STOPDLine to 0.
local ApLine to 0.
local PeLine to 0.
local EccLine to 0.
local Nameline to 0.
local StatLine to 0.
local Diag1Line to 0.
local Diag2Line to 0.
local BnInLine to 0.
local BnDuLine to 0.
local BnDvLine to 0.
local Error1Line to 0.
local Col1Col to 7.
local Col2Col to 35.
local ColSize to 15.
local LineSize to 50.

local function DisplayLabels
  {
// Display the labels, headings and any data that does not change.
// Calculate the line numbers for each datum.
// Notes:
//    - The two blank lines at the top of the screen allow for the
//      "Program ended" message line and the following cursor line.
//
    parameter VesselName.

    local line to 0.

//         -123456789-123456789-123456789-123456789-123456789
//         XXXXXX XXXXXXXXXXXXXXX      XXXXXX XXXXXXXXXXXXXXX
    print "                                                  " at (0,line).
    set line to line+1.
    print "                                                  " at (0,line).
    set line to line+1.
    print "Function: SpaceX Starship Autopilot               " at (0,line).
    set line to line+1.
    print "Vessel Name:                                      " at (0,line).
    set NameLine to line. set line to line+1.
    print "------VESSEL----------      -------AUTOPILOT------" at (0,line).
    set line to line+1.
    print "VSpd:                       TVSpd:                " at (0,line).
    set VSpdLine to line. set TVSpdLine to line. set line to line+1.
    print "ASL:                        Stat:                 " at (0,line).
    set ASLLine to line. set StatLine to line. set line to line+1.
    print "AGL:                                              " at (0,line).
    set AGLLine to line. set line to line+1.
    print "DTT:                                              " at (0,line).
    set DTTLine to line. set line to line+1.
    print "HDTT:                                             " at (0,line).
    set HDTTLine to line. set line to line+1.
    print "STOPD:                                            " at (0,line).
    set STOPDLine to line. set line to line+1.
    print "--------ORBIT---------                            " at (0,line).
    set line to line+1.
    print "Ap:                                               " at (0,line).
    set ApLine to line. set line to line+1.
    print "Pe:                                               " at (0,line).
    set PELine to line. set line to line+1.
    print "Ecc:                                              " at (0,line).
    set EccLine to line. set line to line+1.
    print "----ESTIMATED BURN----                            " at (0,line).
    set line to line+1.
    print "BnIn:                                             " at (0,line).
    set BnInLine to line. set line to line+1.
    print "BnDu:                                             " at (0,line).
    set BnDuLine to line. set line to line+1.
    print "BnDv:                                             " at (0,line).
    Set BnDvLine to line. set line to line+1.
    print "-------ERROR MSG------                            " at (0,line).
    set line to line+1.
    print "                                                  " at (0,line).
    set Error1Line to line. set line to line+1.
    print "-----DIAGNOSTICS------                            " at (0,line).
    set line to line+1.
    print "                                                  " at (0,line).
    set Diag1Line to line. set line to line+1.
    print "                                                  " at (0,line).
    set Diag2Line to line. set line to line+1.

    print VesselName at (13,Nameline).
      
  }

local function DisplayRefresh
    {
// Refresh the changing MFD data on the display.
// Notes:
//    -
      parameter ASL.
      parameter AGL.
      parameter DTT.
      parameter HDTT.
      parameter STOPD.
      parameter VSpd.
      parameter TVSpd.
      parameter Ap.
      parameter Pe.
      parameter Ecc.
      parameter BurnStartTime.
      parameter UTSeconds.

      print MFDVal(round(ASL/1000,3)+" km") at (Col1Col,ASLLine). 
      print MFDVal(round(AGL/1000,3)+" km") at (Col1Col,AGLLine).
      print MFDVal(round(DTT/1000,3)+" km") at (Col1Col,DTTLine).
      print MFDVal(round(HDTT/1000,3)+" km") at (Col1Col,HDTTLine).
      print MFDVal(round(STOPD/1000,3)+" km") at (Col1Col,STOPDLine).
      print MFDVal(round(VSpd,1)+" m/s") at (Col1Col,VSpdLine).
      print MFDVal(round(TVSpd,1)+" m/s") at (Col2Col,TVSpdLine).
      print MFDVal(round(Ap/1000,3)+" km") at (Col1Col,ApLine). 
      print MFDVal(round(Pe/1000,3)+" km") at (Col1Col,PeLine).
      print MFDVal(round(Ecc,5)) at (Col1Col,EccLine).

    if BurnStartTime <> 0
      {
        if BurnStartTime >= UTSeconds
          print MFDVal("T-"+round(abs(UTSeconds-BurnStartTime),1)+" s") at (Col1Col,BnInLine).
        else
          print MFDVal("T+"+round(UTSeconds-BurnStartTime,1)+" s") at (Col1Col,BnInLine).
      }
    }

local function DisplayManeuver
    {
// Update the manuever data.

      parameter BnDu.
      parameter BnDv.

      print MFDVal(round(BnDu,1)+" s") at (7,BnDuLine).
      print MFDVal(round(BnDv,1)+" m/s") at (7,BnDvLine).
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
      parameter ErrorLine1 to "".

      print ErrorLine1:tostring:padright(LineSize) at (0,Error1Line).
    }

local function DisplayDiagnostic
    {
// Update the diagnostic info lines.
      parameter DiagLine1 to "".
      parameter DiagLine2 to "".

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
//}