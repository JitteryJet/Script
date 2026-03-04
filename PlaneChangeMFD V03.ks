// Name: PlaneChangeMFD
// Author: JitteryJet
// Version: V02
// kOS Version: 1.3.2.0
// KSP Version: 1.12.3
// Description:
//    Multi-function Display (MFD) for the PlaneChange program.
//
//Notes:
//    - Coded as an Anonymous Delegate.
//    - Current vessel only ie the vessel running the calling program.
//    - It should be possible to call this script from programs other than PlaneChange,
//      but it was designed with PlaneChange in mind.
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
//    21/07/2020 V01  - Created.
//    24/07/2020 V02  - Replaced bound variables such as SHIP
//                      and TIME with parameters passed from the calling
//                      script - better programming practice.
//    23/12/2021 V03  - WIP.
//                    - Declare local functions LOCAL to ensure they are
//                      not accidentally called from other scripts. The
//                      default scope for a function is GLOBAL.
//                    - Tested KSP 1.12.3.
//                    -
//
// MFD Label Abbreviations:
//  Function      MFD Function Name
//  Vessel Name   Name of the vessel 
//	Ap            Orbit Apoapsis km
//	Pe	          Orbit Periapsis km
//	Inc	          Orbit Inclination deg
//	Stat	        Flight Status
//	BnIn	        Maneuver Burn In Time s
//  BnDu	        Maneuver Burn Duration s
//	BnDv	        Maneuver Burn Delta-v m/s
//  Match         Match Orbital Name
//
@lazyglobal off.
//{
// Expose the delegate lexicon.
  global PlaneChangeMFD to lexicon
    (
      "Displaylabels",DisplayLabels@,
      "DisplayRefresh",DisplayRefresh@,
      "DisplayDiagnostics",DisplayDiagnostics@,
      "DisplayManuever",DisplayManuever@,
      "DisplayFlightStatus",DisplayFlightStatus@
    ).

// Variables to keep track of datum line numbers 
  local ApLine to 0.
  local PeLine to 0.
  local Nameline to 0.
  local Matchline to 0.
  local VIncLine to 0.
  local MIncLine to 0.
  local StatLine to 0.
  local Diag1Line to 0.
  local Diag2Line to 0.
  local BnInLine to 0.
  local BnDuLine to 0.
  local BnDvLine to 0.
  local Colsize to 13.
  local Col1Col to 7.
  local Col2Col to 33.

  local function DisplayLabels
    {
// Display the labels, headings and any data that does not change.
// Calculate the line numbers for each datum.
// Notes:
//    - The two blank lines at the top of the screen allow for the
//      "Program ended" message line and the following cursor line.
//
      parameter VesselName.
      parameter MatchName.
      parameter MatchInclination.

      local line to 0.

//           -123456789-123456789-123456789-123456789-12345
//           XXXXXX XXXXXXXXXXXXX      XXXXXX XXXXXXXXXXXXX
      print "                                              " at (0,line).
      set line to line+1.
      print "                                              " at (0,line).
      set line to line+1.
      print "Function: Plane Change                        " at (0,line).
      set line to line+1.
      print "Vessel Name:                                  " at (0,line).
      set NameLine to line. set line to line+1.
      print "-----VESSEL---------      ------AUTOPILOT-----" at (0,line).
      set line to line+1.
      print "Ap:                       Match:              " at (0,line).
      set ApLine to line. set Matchline to line. set line to line+1.
      print "Pe:                                           " at (0,line).
      set PELine to line. set line to line+1.
      print "Inc:                      Inc:                " at (0,line).
      set VIncLine to line. set MIncLine to line. set line to line+1.
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
      print "-----ERROR MSG----                            " at (0,line).
      set line to line+1.
      print "                                              " at (0,line).
      set line to line+1.
      print "---DIAGNOSTICS----                            " at (0,line).
      set line to line+1.
      print "                                              " at (0,line).
      set Diag1Line to line. set line to line+1.
      print "                                              " at (0,line).
      set Diag2Line to line. set line to line+1.

      print VesselName at (13,Nameline).
      print MFDVal(round(MatchInclination,1)+char(176)) at (Col2Col,MIncLine).
      print MatchName at (Col2Col,Matchline).
    }

  local function DisplayRefresh
    {
// Refresh the MFD data on the display.
// Notes:
//    - Call this function to refresh the screen and so display updated
//      datas.

      parameter apoapsis.
      parameter periapsis.
      parameter inclination.
      parameter BurnStartTime.
      parameter TimeSeconds.


      print MFDVal(round(apoapsis/1000,3)+" km") at (Col1Col,ApLine). 
      print MFDVal(round(periapsis/1000,3)+" km") at (Col1Col,PeLine).
      print MFDVal(round(inclination,1)+char(176)) at (Col1Col,VIncLine).


    if BurnStartTime <> 0
      {
        if BurnStartTime >= TimeSeconds
          print MFDVal("T-"+round(abs(TimeSeconds-BurnStartTime),1)+" s") at (Col1Col,BnInLine).
        else
          print MFDVal("T+"+round(TimeSeconds-BurnStartTime,1)+" s") at (Col1Col,BnInLine).
      }
    }

  local function DisplayManuever
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
      parameter Stat.

      print stat:padright(ColSize) at (Col2Col,StatLine).
    }

  local function DisplayDiagnostics
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

      local ValColSize is 13.
      local FmtVal is "".

      if Val:istype("Scalar")
        set Val to Val:tostring().

      if Val:length >= ValColSize
        set FmtVal to Val:substring(Val:length-ValColSize,ValColSize).
      else
        set FmtVal to Val:padleft(ValColSize).

      return FmtVal.
    }
//}