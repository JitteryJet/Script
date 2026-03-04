// Name: LaunchToInterceptMFD
// Author: JitteryJet
// Version: V01
// kOS Version: 1.4.0.0
// KSP Version: 1.12.5
// Description:
//    Multi-function Display (MFD) for the LaunchToIntercept program
//
// Notes:
//    - The MFD functions are coded using delegates. This technique keeps this kOS function allocated.
//    - The GUI window is created in the caller. This is to allow for widgets
//      that require interaction from the User. ?????
//    - The dynamic data can be refreshed as little or as often as required.
//      The refresh can be done by a trigger, but keep it mind it will use up some of the
//      physics tick.
//    -
//
// Todo:
//    - Fix up layout. It is out of alignment here and there.
//
// Update History:
//    25/03/2025 V01  - WIP. Created.
//                    - 
//
// MFD Label Abbreviations:
//  Function      MFD Function Name.
//  ShipName      Name of this ship.
//  Stage         Stage number.
//  Pitch         Pitch angle above horizon (degrees).
//	Ap            Orbit Apoapsis (km).
//	Pe	          Orbit Periapsis (km).
//  Inc           Orbit Inclination (degrees).
//  Ecc           Orbit Eccentricity.
//	Stat  	      Autopilot Status.
//  Targ          Target Name.
//  SType         Search Type.
//  DStps         Number of Departure Time steps.
//  TStps         Number of Transfer Time steps.
//  SrchT         Search time (s).
//  TurnS         Turn start altitude (km).
//	BnIn	        Maneuver Burn In Time (s).
//  BnDu	        Maneuver Burn Duration (s).
//	BnDv	        Maneuver Burn Delta-v (m/s).
//  DTime         Departure time.
//  TTime         Transfer time.
//  SMA           Transfer Semi-major Axis (km).
//  Dv            Delta-v (m/s).
//  OTyp          Orbit Type.
//  FTTme         Final transfer time after search.
//  FDTme         Final departure time after search.
//  FSMA          Final Transfer Semi-major Axis after search (km).
//  FDv           Final delta-v after search (m/s).
//  FOTyp         Final Orbit Type.
//
@lazyglobal off.

// Parameter descriptions.
//    MFD                           MFD GUI window.

// parameter MFD. 

// Expose the delegates.
global MFDFunctions to lexicon
  (
    "DisplayCreate",DisplayCreate@,
    "DisplayRefresh",DisplayRefresh@,
    "DisplayDiagnostic",DisplayDiagnostic@,
    "DisplayManeuver",DisplayManeuver@,
    "DisplayFlightStatus",DisplayFlightStatus@,
    "DisplayError",DisplayError@,
    "DisplaySearch",DisplaySearch@,
    "DisplaySearchResults",DisplaySearchResults@
  ).

local VeryBigNumber to 3.402823E+38.

// Define the GUI widgets in the outermost scope to
// allow them to be referenced by any of the delegates.
// I am not sure if this is the "correct" method to
// use but I am going with it for now.
local MFD to "".
local FunctionLabel to "".
local ShipNameLabel to "".
local ColumnsBox to "".
local Column1Box to "".
local Column2Box to "".
local ShipBox to "".
local ShipHeadingLabel to "".
local ShipBodyBox to "".
local ShipBodyColABox to "".
local ShipBodyColBBox to "".
local StageLabel to "".
local StageDatum to "".
local PitchLabel to "".
local PitchDatum to "".
local AutopilotBox to "".
local AutopilotHeadingLabel to "".
local StatLabel to "".
local TargLabel to "".
local STypeLabel to "".
local DStpsLabel to "".
local TStpsLabel to "".
local SrchTLabel to "".
local TurnSLabel to "".
local OrbitBox to "".
local OrbitBodyBox to "".
local OrbitBodyColABox to "".
local OrbitBodyColBBox to "".
local OrbitHeadingLabel to "".
local ApLabel to  "".
local ApDatum to "".
local PeLabel to  "".
local PeDatum to "".
local IncLabel to "".
local IncDatum to "".
local EccLabel to "".
local EccDatum to "".
local SearchBox to "".
local SearchBodyBox to "".
local SearchBodyColABox to "".
local SearchBodyColBBox to "".
local SearchBoxHeadingLabel to "".
local DTimeLabel to "".
local DTimeDatum to "".
local TTimeLabel to "".
local TTimeDatum to "".
local SMALabel to "".
local SMADatum to "".
local DvLabel to "".
local DvDatum to "".
local OTypLabel to "".
local OTypDatum to "".
local SearchResultsBox to "".
local SearchResultsBodyBox to "".
local SearchResultsBodyColABox to "".
local SearchResultsBodyColBBox to "".
local SearchResultsBoxHeading to "".
local FDTmeLabel to "".
local FDTmeDatum to "".
local FTTmeLabel to "".
local FTTmeDatum to "".
local FSMALabel to  "".
local FSMADatum to "".
local FDvLabel to  "".
local FDvDatum to "".
local FOTypLabel to "".
local FOTypDatum to "".
local ManeuverBurnBox to "".
local ManeuverBurnHeadingLabel to "".
local ManeuverBurnBodyBox to "".
local ManeuverBurnBodyColABox to "".
local ManeuverBurnBodyColBBox to "".
local BnInLabel to "".
local BnInDatum to "".
local BnDuLabel to "".
local BnDuDatum to "".
local BnDvLabel to "".
local BnDvDatum to "".
local ErrorMsgBox to "".
local ErrorMsgBoxHeading to "".
local Error1Datum to "".
local DiagnosticsBox to "".
local DiagnosticsBoxHeading to "".
local Diag1Datum to "".
local Diag2Datum to "".

local function DisplayCreate
  {
// Create the Display.
// Notes:
//    - Create the Display and set the field labels and
//      field data that will not be updated again.
//
    parameter MyShipName.
    parameter TargetName.
    parameter SearchType.
    parameter DepartureTimeSteps.
    parameter TransferTimeSteps.
    parameter SearchTime.
    parameter TurnStartAlt.

    set MFD to gui(0).
    set MFD:skin:box:hstretch to true.
    set MFD:skin:label:wordwrap to false.
    set MFD:skin:label:margin:top to 0.
    set MFD:skin:label:margin:bottom to 0.
  //  set MFD:skin:label:padding:h to 0.
  //  set MFD:skin:label:padding:v to 0.
    set MFD:skin:box:margin:top to 0.
    set MFD:skin:box:margin:bottom to 0.   
    set MFD:skin:box:margin:left to 0.
    set MFD:skin:box:margin:right to 0.
    set MFD:skin:box:padding:h to 5.
    set MFD:skin:box:padding:v to 5.
    set MFD:skin:flatlayout:margin:top to 0.
    set MFD:skin:flatlayout:margin:bottom to 0.
    set MFD:skin:flatlayout:margin:left to 0.
    set MFD:skin:flatlayout:margin:right to 0.
//    set MFD:skin:flatlayout:padding:h to 5.
//    set MFD:skin:flatlayout:padding:v to 5.

// I tried to pick a font that should be installed on everyone's computer.
// Monospace fonts line up the best and are more compact than other fonts.
//    set MFD:skin:font to "Arial".
    set MFD:skin:font to "Consolas".

    set MFD:skin:label:fontsize to 18.
    set MFD:skin:label:textcolor to white.

    set FunctionLabel to MFD:addlabel("Function: Launch To Intercept").
    set ShipNameLabel to MFD:addlabel("Ship Name: "+MyShipName).

// Alignment guide for column Boxes.
// -123456789-123456789-1234
// XXXXXX XXXXXXXXXXXXXXXXXX

// Columns box.
// The top-most GUI box has a vertical flow which cannot be
// changed. Therefore another box with horizontal flow has to
// be created to get two columns.
    set ColumnsBox to MFD:addhlayout.
    set Column1Box to ColumnsBox:addvlayout.
    ColumnsBox:addspacing(25).
    set Column2Box to ColumnsBox:addvlayout.

// Ship box.
    set ShipBox to Column1Box:addvbox.
    set ShipHeadingLabel to ShipBox:addlabel("----------SHIP-----------"). 
    set ShipBodyBox to ShipBox:addhlayout.
    set ShipBodyColABox to ShipBodyBox:addvlayout.
    set ShipBodyColBBox to ShipBodyBox:addvlayout.
    set StageLabel to ShipBodyColABox:addlabel("Stage: ").
    set StageDatum to ShipBodyColBBox:addlabel().
    set StageDatum:style:align to "RIGHT".
    set PitchLabel to ShipBodyColABox:addlabel("Pitch: ").
    set PitchDatum to ShipBodyColBBox:addlabel().
    set PitchDatum:style:align to "RIGHT".

// Autopilot box.
    set AutopilotBox to Column2Box:addvbox.
    set AutopilotHeadingLabel to AutopilotBox:addlabel("--------AUTOPILOT--------").
    set StatLabel to AutopilotBox:addlabel("Stat: ").
    set TargLabel to AutopilotBox:addlabel("Targ: "+TargetName).
    set STypeLabel to AutopilotBox:addlabel("SType: "+SearchType).
    set DStpsLabel to AutopilotBox:addlabel("DStps: "+DepartureTimeSteps:tostring).
    set TStpsLabel to AutopilotBox:addlabel("TStps: "+TransferTimeSteps:tostring).
    set SrchTLabel to AutopilotBox:addlabel("SrchT: "+SearchTime:tostring+" s").
    set TurnSLabel to AutopilotBox:addlabel("TurnS: "+round(TurnStartAlt/1000,3)+" km").

// Orbit box.
    set OrbitBox to Column1Box:addvbox.
    set OrbitHeadingLabel to OrbitBox:addlabel("----------ORBIT----------").
    set OrbitBodyBox to OrbitBox:addhlayout.
    set OrbitBodyColABox to OrbitBodyBox:addvlayout.
    set OrbitBodyColBBox to OrbitBodyBox:addvlayout.
    set ApLabel to OrbitBodyColABox:addlabel("Ap: ").
    set ApDatum to OrbitBodyColBBox:addlabel().
    set ApDatum:style:align to "RIGHT".
    set PeLabel to OrbitBodyColABox:addlabel("Pe: ").
    set PeDatum to OrbitBodyColBBox:addlabel().
    set PeDatum:style:align to "RIGHT".
    set IncLabel to OrbitBodyColABox:addlabel("Inc: ").
    set IncDatum to OrbitBodyColBBox:addlabel().
    set IncDatum:style:align to "RIGHT".
    set EccLabel to OrbitBodyColABox:addlabel("Ecc: ").
    set EccDatum to OrbitBodyColBBox:addlabel().
    set EccDatum:style:align to "RIGHT".

// Search box.
    set SearchBox to Column2Box:addvbox.
    set SearchBoxHeadingLabel to SearchBox:addlabel("---------SEARCH----------").
    set SearchBodyBox to SearchBox:addhlayout.
    set SearchBodyColABox to SearchBodyBox:addvlayout.
    set SearchBodyColBBox to SearchBodyBox:addvlayout.
    set DTimeLabel to SearchBodyColABox:addlabel("DTime: ").
    set DTimeDatum to SearchBodyColBBox:addlabel(" ").
    set DTimeDatum:style:align to "RIGHT".
    set TTimeLabel to SearchBodyColABox:addlabel("TTime: ").
    set TTimeDatum to SearchBodyColBBox:addlabel(" ").
    set TTimeDatum:style:align to "RIGHT".
    set SMALabel to SearchBodyColABox:addlabel("SMA: ").
    set SMADatum to SearchBodyColBBox:addlabel(" ").
    set SMADatum:style:align to "RIGHT".
    set DvLabel to SearchBodyColABox:addlabel("Dv: ").
    set DvDatum to SearchBodyColBBox:addlabel(" ").
    set DvDatum:style:align to "RIGHT".
    set OTypLabel to SearchBodyColABox:addlabel("OTyp: ").
    set OTypDatum to SearchBodyColBBox:addlabel(" ").
    set OTypDatum:style:align to "RIGHT".

// Search Results box.
    set SearchResultsBox to Column2Box:addvbox.
    set SearchResultsBoxHeading to SearchResultsBox:addlabel("-----SEARCH RESULTS------").
    set SearchResultsBodyBox to SearchResultsBox:addhlayout.
    set SearchResultsBodyColABox to SearchResultsBodyBox:addvlayout.
    set SearchResultsBodyColBBox to SearchResultsBodyBox:addvlayout.
    set FDTmeLabel to SearchResultsBodyColABox:addlabel("FDTme: ").
    set FDTmeDatum to SearchResultsBodyColBBox:addlabel(" ").
    set FDTmeDatum:style:align to "RIGHT".
    set FTTmeLabel to SearchResultsBodyColABox:addlabel("FTTme: ").
    set FTTmeDatum to SearchResultsBodyColBBox:addlabel(" ").
    set FTTmeDatum:style:align to "RIGHT".
    set FSMALabel to  SearchResultsBodyColABox:addlabel("FSMA: ").
    set FSMADatum to SearchResultsBodyColBBox:addlabel(" ").
    set FSMADatum:style:align to "RIGHT".
    set FDvLabel to  SearchResultsBodyColABox:addlabel("FDv: ").
    set FDvDatum to SearchResultsBodyColBBox:addlabel(" ").
    set FDvDatum:style:align to "RIGHT".
    set FOTypLabel to SearchResultsBodyColABox:addlabel("FOTyp: ").
    set FOTypDatum to SearchResultsBodyColBBox:addlabel(" ").
    set FOTypDatum:style:align to "RIGHT".

// Maneuver Burn box.
    set ManeuverBurnBox to Column1Box:addvbox.
    set ManeuverBurnHeadingLabel to ManeuverBurnBox:addlabel("------MANEUVER BURN------").
    set ManeuverBurnBodyBox to ManeuverBurnBox:addhlayout.
    set ManeuverBurnBodyColABox to ManeuverBurnBodyBox:addvlayout.
    set ManeuverBurnBodyColBBox to ManeuverBurnBodyBox:addvlayout.
    set BnInLabel to ManeuverBurnBodyColABox:addlabel("BnIn: ").
    set BnInDatum to ManeuverBurnBodyColBBox:addlabel(" ").
    set BnInDatum:style:align to "RIGHT".
    set BnDuLabel to ManeuverBurnBodyColABox:addlabel("BnDu: ").
    set BnDuDatum to ManeuverBurnBodyColBBox:addlabel(" ").
    set BnDuDatum:style:align to "RIGHT".
    set BnDvLabel to ManeuverBurnBodyColABox:addlabel("BnDv: ").
    set BnDvDatum to ManeuverBurnBodyColBBox:addlabel(" ").
    set BnDvDatum:style:align to "RIGHT".

// Error Message box.
    set ErrorMsgBox to MFD:addvlayout.
    set ErrorMsgBoxHeading to ErrorMsgBox:addlabel("--------ERROR MSG--------").
    set Error1Datum to ErrorMsgBox:addlabel().

// Diagnostics box.
    set DiagnosticsBox to MFD:addvlayout.
    set DiagnosticsBoxHeading to DiagnosticsBox:addlabel("-------DIAGNOSTICS-------").
    set Diag1Datum to DiagnosticsBox:addlabel("").
    set Diag2Datum to DiagnosticsBox:addlabel("").

    MFD:show().
  }

local function DisplayRefresh
  {
// Refresh the MFD data on the display.
// Notes:
//    - 
    parameter StageNum.
    parameter pitch.
    parameter Ap.
    parameter Pe.
    parameter Inc.
    parameter Ecc.
    parameter ManeuverStartTStmp.
    parameter CurrentTStmp.

    set StageDatum:text to StageNum:tostring(). 
    set PitchDatum:text to round(pitch,1)+char(176).
    set ApDatum:text to round(Ap/1000,3)+" km". 
    set PeDatum:text to round(Pe/1000,3)+" km".
    set IncDatum:text to round(Inc,1)+char(176).
    set EccDatum:text to round(Ecc,4):tostring().
    if ManeuverStartTStmp = timestamp(0)
      set BnInDatum:text to "".
    else
      {
        if ManeuverStartTStmp > CurrentTStmp
          set BnInDatum:text to "T-"+round(abs((CurrentTSTmp-ManeuverStartTStmp):seconds),1)+" s".
        else
          set BnInDatum:text to "T+"+round((CurrentTSTmp-ManeuverStartTStmp):seconds,1)+" s".
      }
  }

local function DisplayManeuver
  {
// Display the maneuver data.

    parameter BnDu.
    parameter BnDv.

    set BnDuDatum:text to round(BnDu,2)+" m/s".
    set BnDvDatum:text to round(BnDv,2)+" m/s".
  }

local function DisplaySearch
  {
// Update the search data.

    parameter DTime.
    parameter TTime.
    parameter SMA.
    parameter Dv.
    parameter ShortWayOrbit.

    local DTimeFormatted to "Y"+DTime:year+"D"+DTime:day+" "+DTime:clock.

    set DTimeDatum:text to DTimeFormatted.
    set TTimeDatum:text to TTime:full.
    set DvDatum:text to round(Dv,2)+" m/s".
    if SMA = VeryBigNumber
      set SMADatum:text to "Infinity".
    else
      set SMADatum:text to round(SMA/1000,3)+" km".
    if ShortWayOrbit
      set OTypDatum:text to "Short Way orbit".
    else
      set OTypDatum:text to "Long Way orbit".

  }

local function DisplaySearchResults
  {
// Update the search results data.

    parameter FDTme.
    parameter FTTme.
    parameter FSMA.
    parameter FDv.
    parameter FShortWayOrbit.

    local FDTmeFormatted to "Y"+FDTme:year+"D"+FDTme:day+" "+FDTme:clock.

    set FDTmeDatum:text to FDTmeFormatted.
    set FTTmeDatum:text to FTTme:full.
    set FDvDatum:text to round(FDv,2)+" m/s".
    if FSMA = VeryBigNumber
      set FSMADatum:text to "Infinity".
    else
      set FSMADatum:text to round(FSMA/1000,3)+" km".
    if FShortWayOrbit
      set FOTypDatum:text to "Short Way orbit".
    else
      set FOTypDatum:text to "Long Way orbit".
  }

local function DisplayFlightStatus
  {
// Update the Flight Status data.

    parameter mystatus.

    set StatLabel:text to "Stat: "+mystatus.
  }

local function DisplayError
  {
// Update the error info lines.
    parameter ErrorLine1.

    set Error1Datum:text to ErrorLine1.
  }

local function DisplayDiagnostic
  {
// Update the diagnostic info lines.
    parameter DiagLine1.
    parameter DiagLine2.

    set Diag1Datum:text to DiagLine1:tostring().
    set Diag2Datum:text to DiagLine2:tostring().
  }