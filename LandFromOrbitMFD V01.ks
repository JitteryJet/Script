// Name: CaptureOrbitMFD
// Author: JitteryJet
// Version: V01
// kOS Version: 1.3.2.0
// KSP Version: 1.11.2
// Description:
//    Multi-function Display (MFD) for the LandFromOrbit program.
//
//Notes:
//    - Coded using Delegates.
//    - Current vessel only ie the vessel running the calling program.
//    - It should be possible to call this script from programs other than LandFromOrbit,
//      but it was designed with LandFromOrbit in mind.
//    - The clearscreen and a big enough terminal size are set in the caller, I didn't want to
//      make any assumptions about how the caller might want the terminal set.
//    - The screen can be refreshed as little or as often as possible.
//      The refresh can be done by a trigger, but keep it mind it will use up some of the
//      physics tick.
//
// Todo:
//    -
//
// Update History:
//    26/03/2021 V01  - Created. WIP. 
//
// MFD Label Abbreviations:
//  Function      MFD Function Name.
//  Vessel Name   Name of this vessel .
//	Ap            Orbit Apoapsis (km).
//	Pe	          Orbit Periapsis (km).
//	Stat	        Flight Status
//	BnIn	        Maneuver Burn In Time (s).
//  BnDu	        Maneuver Burn Duration (s).
//	BnDv	        Maneuver Burn Delta-v (m/s).
//  TTIM          Time To Impact (s).
//
@lazyglobal off.
//{
// Expose the delegates.
global LandFromOrbitMFD to lexicon
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
  local Nameline to 0.
  local StatLine to 0.
  local Diag1Line to 0.
  local Diag2Line to 0.
  local BnInLine to 0.
  local BnDuLine to 0.
  local BnDvLine to 0.
  local Error1Line to 0.
  local TTIMLine to 0.
  local Col1Col to 7.
  local Col2Col to 33.
  local ColSize is 13.

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

//           -123456789-123456789-123456789-123456789-12345
//           XXXXXX XXXXXXXXXXXXX      XXXXXX XXXXXXXXXXXXX
      print "                                              " at (0,line).
      set line to line+1.
      print "                                              " at (0,line).
      set line to line+1.
      print "Function: Land From Orbit                     " at (0,line).
      set line to line+1.
      print "Vessel Name:                                  " at (0,line).
      set NameLine to line. set line to line+1.
      print "-----VESSEL---------      ------AUTOPILOT-----" at (0,line).
      set line to line+1.
      print "Ap:                                           " at (0,line).
      set ApLine to line. set line to line+1.
      print "Pe:                                           " at (0,line).
      set PELine to line. set line to line+1.
      print "                          Stat:               " at (0,line).
       set StatLine to line. set line to line+1.
      print "---ESTIMATED BURN--                           " at (0,line).
      set line to line+1.
      print "BnIn:                                         " at (0,line).
      set BnInLine to line. set line to line+1.
      print "BnDu:                                         " at (0,line).
      set BnDuLine to line. set line to line+1.
      print "BnDv:                                         " at (0,line).
      Set BnDvLine to line. set line to line+1.
      print "------SUICIDE------                           " at (0,line).
      set line to line+1.
      print "TTIM:                                         " at (0,line).
      set TTIMLine to line. set line to line+1.
      print "-----ERROR MSG----                            " at (0,line).
      set line to line+1.
      print "                                              " at (0,line).
      set Error1Line to line. set line to line+1.
      print "---DIAGNOSTICS----                            " at (0,line).
      set line to line+1.
      print "                                              " at (0,line).
      set Diag1Line to line. set line to line+1.
      print "                                              " at (0,line).
      set Diag2Line to line. set line to line+1.

      print VesselName at (13,Nameline).
      
    }

  local function DisplayRefresh
    {
// Refresh the MFD data on the display.
// Notes:
//    - This is to display the datas that keep changing.

      parameter ap.
      parameter pe.
      parameter BurnStartTime.
      parameter TimeSeconds.
      parameter ImpactTime.

      print MFDVal(round(ap/1000,3)+" km") at (Col1Col,ApLine). 
      print MFDVal(round(pe/1000,3)+" km") at (Col1Col,PeLine).

    if BurnStartTime = 0
      {
        print "":padright(ColSize) at (Col1Col,BnInLine).
      }
    else
      {
        if BurnStartTime >= TimeSeconds
          print MFDVal("T-"+round(abs(TimeSeconds-BurnStartTime),1)+" s") at (Col1Col,BnInLine).
        else
          print MFDVal("T+"+round(TimeSeconds-BurnStartTime,1)+" s") at (Col1Col,BnInLine).
      }
    if ImpactTime = 0
      {
        print "":padright(ColSize) at (Col1Col,TTIMLine).
      }
    else
      {
        if ImpactTime >= TimeSeconds
          print MFDVal("T-"+round(abs(TimeSeconds-ImpactTime),1)+" s") at (Col1Col,TTIMLine).
        else
          print MFDVal("T+"+round(TimeSeconds-ImpactTime,1)+" s") at (Col1Col,TTIMLine).
      }
    }

  local function DisplayManuever
    {
// Display the manuever data.

      parameter BnDu.
      parameter BnDv.

      print MFDVal(round(BnDu,1)+" s") at (7,BnDuLine).
      print MFDVal(round(BnDv,1)+" m/s") at (7,BnDvLine).
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

      print (ErrorLine1) at (0,Error1Line).
    }

  local function DisplayDiagnostic
    {
// Display the diagnostic info lines.
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
//}