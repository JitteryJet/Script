// CareerLib1. Library of functions.
// Used in the "Kerbal Career Using kOS" YouTube series.

global function CalcEllipticalTransferOrbitDeltaV
  {
// Calculate the delta-v required for an elliptical transfer orbit.
// Notes:
//    - Transfer orbit is from one orbital to another orbiting
//      the same parent body.
//    - Refer to the "Vis-viva" equation.

    parameter TargetOrbitRadius.
    parameter ShipOrbitRadius.
    parameter ShipV.
    parameter mu.

    local DeltaV to 0.0.
    local a to 0.0.
    local vel to 0.0.
    
    set a to (TargetOrbitRadius+ShipOrbitRadius)/2.
    set vel to sqrt(mu*(2/ShipOrbitRadius-1/a)).
    set DeltaV to vel-ShipV.
    return DeltaV.
  }

global function CalcBurnTimeFromDeltaV
  {
// Calculate the burn time for the specified deltaV based on the vessel
// characteristics. 
// Notes:
//    - The equation allows for changes in mass as fuel is burnt.
//      Refer to the "Ideal Rocket Equation".
//    - The estimate assumes that thrust and ISP remain constant. These
//      assumptions do not allow for any staging etc that can occur during a
//      burn.
    parameter Dv to 0.0.

    local minitial is 0.0.
    local mfinal is 0.0.
    local ISP is 0.0.
    local g0 is constant:g0.
    local mpropellent is 0.0.
    local mdot is 0.0.
    local thrust is 0.0.
    local BurnTime is 0.0.

    set minitial to ship:mass.
    set thrust to ship:availablethrust.
    set ISP to CalcCurrentISP().

    set mfinal to minitial*constant:e^(-Dv/(ISP*g0)).
    set mpropellent to minitial-mfinal.
    set mdot to thrust/(ISP*g0).
    set BurnTime to mpropellent/mdot.

    return BurnTime.
  }

global function CalcTrueAnomalyFromVec
  {
// Calculate the true anomaly angle from a true anomaly vector pointing
// from the centre of the body to a point in the orbit.
// Notes:
//    - Returns an angle 0-360 degress.
//    - I found this code on the Internet.
//
// Todo:
//    - Try and find a less complicated method that does
//      not require the normal to the orbit parameter.

    parameter TrueAnomalyVec.
    parameter EccentricityVec.
    parameter OrbitNormalVec.

// Calculate the smaller angle between the point on the orbit and the periapsis.
    local angle to vang(TrueAnomalyVec,EccentricityVec).

// Determine which quadrant the point on the orbit lies in,
// and adjust the angle to the correct value.
    if vang(TrueAnomalyVec,vcrs(OrbitNormalVec,EccentricityVec)) < 90
      return angle.
    else
      return 360-angle. 
  }

global function CalcOrbitPositionETA
  {
// Calculate the time for an orbital to orbit from an initial position to a
// final position.
// Notes:
//    - 
// Todo:
//    - 

    parameter InitialTrueAnomaly.
    parameter FinalTrueAnomaly.
    parameter eccentricity.
    parameter period.

    local t to 0.
    local InitialMeanAnomaly to
      CalcMeanAnomalyFromTrue(InitialTrueAnomaly,eccentricity).
    local FinalMeanAnomaly to
      CalcMeanAnomalyFromTrue(FinalTrueAnomaly,eccentricity).

    if InitialMeanAnomaly <= FinalMeanAnomaly
      set t to (FinalMeanAnomaly-InitialMeanAnomaly)/360 * period.
    else
      set t to (FinalMeanAnomaly-InitialMeanAnomaly+360)/360 * period.

    return t.
  }

global function CalcEccentricityVec
  {
// Calculate the Eccentricty Vector for an orbit.
// Notes:
//    - Think of this as the line from the
//      centre of the body to the periapsis.
//    - The magnitude of the vector is the eccentricity
//      of the orbit.
//    - It also defines the Line of Apsides.
// Todo
//    - 
    parameter PositionVec.
    parameter VelocityVec.
    parameter mu.

    local NormalVec to v(0,0,0).
    local EccentrictyVec to v(0,0,0).

// Version 1 of the calculation.
//    set EccentrictyVec to
//      (VelocityVec:mag^2/mu-1/PositionVec:mag)*PositionVec
//      -vdot(PositionVec,VelocityVec)/mu*VelocityVec.

// Version 2 of the calculation.
    set NormalVec to vcrs(PositionVec,VelocityVec).
    set EccentrictyVec to
      vcrs(VelocityVec,NormalVec)/mu-PositionVec/PositionVec:mag.

    return EccentrictyVec.
  }

global function CalcMeanAnomalyFromTrue
  {
// Calculate the Mean Anomaly from the True Anomaly.
// Notes:
//    - It's magic. It works by using the "eccentric anomaly" as an
//      intermediate variable.
//    - kOS orbital angles are given in degrees. These must be converted to radians
//      for this formula to work.
// Todo:
//    - 

    parameter TrueAnomaly.
    parameter eccentricity.

    local EccentricAnomaly to
      CalcEccentricAnomalyFromTrue(TrueAnomaly,eccentricity).
    local EccentricAnomalyRad to EccentricAnomaly*constant:DegToRad.

    local MeanAnomalyRad to
      EccentricAnomalyRad-(eccentricity*sin(EccentricAnomaly)).

    return MeanAnomalyRad*constant:RadtoDeg.
  }

global function CalcEccentricAnomalyFromTrue
  {
// Calculate the Eccentric Anomaly from the True Anomaly.
// Notes:
//    - 
// Todo:
//    - Test for true anomaly values >= 360.
//    -

    parameter TrueAnomaly.
    parameter eccentricity.

    local EccentricAnomaly is
      arccos((eccentricity+cos(TrueAnomaly))/(1+eccentricity*cos(TrueAnomaly))).

    if TrueAnomaly > 180
      set EccentricAnomaly to 360-EccentricAnomaly.

    return EccentricAnomaly.
  }

global function CalcPlaneChangeDeltaVVec
  {
// Calculate the velocity change required for a plane change.
// Assumptions:
//    - The plane change is done at the Ascending Node.
// Notes:
//    - The calculations based on the "Isosceles Triangle" method.

    parameter RelativeInclinationAng.
    parameter OrbitalVelocityVec.
    parameter PositionVec.

    local DeltaVVec to v(0,0,0).
    local rotation to r(0,0,0).
    local NewVelocityVec to v(0,0,0).

    set rotation to angleaxis(RelativeInclinationAng,PositionVec).
    set NewVelocityVec to rotation*OrbitalVelocityVec.

    set DeltaVVec to NewVelocityVec-OrbitalVelocityVec.

    return DeltaVVec.
  }

global function DoWarpSpeed
  {
// Switch on the timewarp if it is not already on.
// Notes:
//    - The higher the level of warp , the higher the chance script code
//      that comes after the warp will be skipped.

    parameter Warptype.  // PHYSICS, RAILS.
    parameter WarpIndex. // 1 to 7.

    wait until kuniverse:timewarp:issettled.
    if kuniverse:timewarp:warp = 0
      {
        set kuniverse:timewarp:mode to Warptype.
        set kuniverse:timewarp:warp to WarpIndex.
      }
  }

global function DoWarpTo
  {
// Timewarp to a point in time.

    parameter WarpToSeconds.
    parameter Warptype.

    wait until kuniverse:timewarp:issettled.
    if kuniverse:timewarp:warp = 0
      {
        set kuniverse:timewarp:mode to Warptype.
        kuniverse:timewarp:warpto(WarpToSeconds).
      }
  }

global function StopWarpSpeed
  {
// Stop the timewarp.
    kuniverse:timewarp:cancelwarp().
    wait until kuniverse:timewarp:issettled.
  }

global function PlayKerbalWave
  {
// Play the Kerbal "Wave" animation.
// Note:
//    -
    addons:eva:playanimation("Wave").
    wait 3.
  }

global function PlayKerbalSalute
  {
// Play the Kerbal salute animation.
// Note:
//    -
    addons:eva:playanimation("idle_g").
    wait 5.
  }

global function PlayKerbalArseScratch
  {
// Play the Kerbal arse scratch animation.
// Note:
//    - This animation is only loaded for male kerbals?
    addons:eva:playanimation("idle_f").
    wait 4.
  }

global function LoadAnimations
  {
// Load Kerbal animations.
    addons:eva:loadanimation("\kOS-EVA\Anims\Wave.anim").
  }

global function StoreKerbalExperiments
  {
// Store results from experiments run on the Kerbal eg EVA Reports.
// Note:
//    - Run this function to store the data without having to
//      board the Kerbal. Boarding the Kerbal may bring up a
//      manual intervention dialog if the Kerbal has experiment 
//      results that are already stored in the part.
//    - The part has to be near the Kerbal.
//    - If the experiment result is already stored in the part
//      the new one is dumped.
// Todo:
//    - This function needs to be rewritten.
//    - This function needs more testing. I can think of plenty of scenarios
//      where it might break eg does the Science Experiment "dump" remove
//      anything from the lists while they are still being processed? 

    parameter part.

    local KerbalMSEList to list().
    local PartMSCList to list().
    local k to 0. 
    local kd to 0.
    local p to 0.
    local pd to 0.
    local ExperimentAlreadyStored to false.
    local KerbalHasData to false.

    set KerbalMSEList to ship:modulesnamed("ModuleScienceExperiment").
    set PartMSCList to part:modulesnamed("ModuleScienceContainer").

    until k = KerbalMSEList:length
      {
        set ExperimentAlreadyStored to false.
        if KerbalMSEList[k]:hasdata
          {
            set kd to 0.
            until kd = KerbalMSEList[k]:data:length
              {
                set p to 0.
                until p = PartMSCList:length
                  {
                    if PartMSCList[p]:hasdata
                      {
                        set pd to 0.
                        until pd = PartMSCList[p]:data:length
                          {
//                            print KerbalMSEList[k]:data[kd]:title.
//                            print PartMSCList[p]:data[pd]:title.
                            if (PartMSCList[p]:data[pd]:title =
                                KerbalMSEList[k]:data[kd]:title)
                              {
                                set ExperimentAlreadyStored to true.
                                break.
                              }
                            set pd to pd+1.
                          }
                      }
                    set p to p+1.
                  }
                set kd to kd+1.
              }
            if ExperimentAlreadyStored
              {
                KerbalMSEList[k]:dump().
                wait 0.
              }
            else
              set KerbalHasData to true.
          }
        set k to k+1.
      }
    if KerbalHasData
      addons:eva:doevent(part,"store experiments").
  }

global function BoardKerbal
  {
// Board the Kerbal. This despawns the Kerbal on the hatch.
    addons:eva:board.
  }

global function GoEVA
  {
// Go EVA. This spawns the Kerbal on the hatch.
    addons:eva:goeva(ship:crew[0]).
  }

global function DoKerbalExperiment
  {
// Do a Kerbal (EVA) Science Experiment.
// Notes:
//    - An existing experiment result held by the Kerbal will not be overwritten.
//    - Attemping to run an experiment in the wrong situation
//      will display an error message on the screen and may
//      cause this kOS function to wait forever.
 
    parameter ExperimentName.

    local found to false.
    local MSEList to list().
    local MSE to "".

// These are the only experiments I have tested at this point in time.
    if ExperimentName = "eva report"
      or ExperimentName = "perform eva science"
      or ExperimentName = "take surface sample"
      {}
    else
      print 0/0. // Unknown EVA Science Experiment name.

    set MSEList to ship:modulesnamed("ModuleScienceExperiment").
    for m in MSEList
      {
        for a in m:allactionnames
          {
            if a = ExperimentName
              {
                set found to true.
                set MSE to m.
                break.
              }
          }
      }
    if not found
      print 0/0.  // Science Experiment Module not found.
    if not MSE:deployed
      {
        MSE:deploy().
        wait until MSE:hasdata.
      }
  }

global function DoVesselScienceExperiments
  {
// Do all the scientific experiments on a vessel.
// Notes:
//    - Scientific experiments includes the Crew Report.
//    - An existing experiment result will not be overwritten.
//    - Attemping to run an experiment in the wrong situation
//      will display an error message on the screen and may
//      cause this kOS function to wait forever.
// Todo:
//    - Test magnetometer report code in space. 
//    - Test seismic scan in all situations.
    local ModuleList to ship:modulesnamed("ModuleScienceExperiment").
    local MagnetometerReportFound to false.
    local SeismicScanFound to false.
    local MaterialsStudyFound to false.
    for module in ModuleList
      {
        if module:hasdata
          break.
        set MagnetometerReportFound to false.
        set SeismicScanFound to false.
        set MaterialsStudyFound to false.
        for ActionName in module:allactionnames
          {
            if ActionName="run magnetometer report"
              {
                set MagnetometerReportFound to true.
                break.
              }
            else
            if ActionName="log seismic data"
              {
                set SeismicScanFound to true.
                break.
              }
            else
            if ActionName="conduct materials study"
              {
                set MaterialsStudyFound to true.
                break.
              }
          }
        if MagnetometerReportFound
          {
            if ship:status="SUB_ORBITAL"
              or ship:status="ORBITING"
              or ship:status="ESCAPING"
              {
                module:deploy.
                wait until module:hasdata.
              }
          }
        else
        if SeismicScanFound
          {
            if ship:status="PRELAUNCH"
              or ship:status="LANDED"
              {
                module:deploy.
                wait until module:hasdata.
              }
          }
        else
        if MaterialsStudyFound
          {
            module:deploy.
            wait until module:hasdata.
// Workaround for the event unavailable right now bug. Sometimes the animation
// for the material bay doors opening has not completed or something.
            wait 0.
            module:part:getmodule("ModuleAnimateGeneric")
              :doevent("close doors").
          }
        else
          {
            module:deploy.
            wait until module:hasdata.
          }
      }
  }

global function ArmTheKlaw
  {
// Arm the Klaw (Advanced Grabbing Unit).
// Notes:
//    - Only arms the first Klaw it finds.
    local PartList to
      ship:partsnamedpattern("^(?:GrapplingDevice|smallClaw)$").
//    print PartList.
    local Module to PartList[0]:getmodule("ModuleAnimateGeneric").
    Module:doevent("arm").
  }

global function CalcCurrentISP
  {
// Calculate the current ISP of the vessel.
// Notes:
//    -
// Todo:
//    - Does not allow for different engine types on the stage - the contribution
//      to the ISP is probably dependent on the thrust of the engine as well.
//    - Check this code with multiple engines, it does not look right!
//    - 
//    
    local ISP is 0.0.
    local englist is list().
    list engines in englist.
    for eng in englist
      {
        if eng:stage = stage:number
          set ISP to ISP + eng:vacuumisp.
      }
    return ISP.
  }

global function CreateStagingTrigger
  {
// Create a trigger to stage automatically.
// Notes:
//    - STAGE 0 is not staged. The assumption is this stage contains
//      the parachute etc.
//		- When the trigger is created, it is assumed the current stage has
//      already been staged and the resource values are non-zero.
//    - Sometimes an engine can flame out even if it has a tiny amount
//      of fuel remaining, amend the code if necessary.
// Todo:
//		- Handle sepratrons correctly. They contribute to the solid fuel value
//      on a stage.

    until stage:ready {wait 0.}
    when
      ship:maxthrust = 0
      or (stage:liquidfuel = 0 and stage:solidfuel = 0)
    then
      {
        stage.
        until stage:ready {wait 0.}
        return stage:number > 0.
      }
  }

global function CreateMapScreenToggleTrigger
  {
// Create a trigger to toggle between the map screen and flight
// screen periodically.
// Notes:
//    -
// Todo:
//		- Allow for warping.

    local MapDisplaySecs to 40.
    local FlightDisplaySecs to 120.
    local NextToggleSecs to timestamp():seconds.
    when timestamp():seconds > NextToggleSecs
    then
      {
        if mapview
          {
            set mapview to false.
            set NextToggleSecs to NextToggleSecs+FlightDisplaySecs.
          }
        else
          {
            set mapview to true.
            set NextToggleSecs to NextToggleSecs+MapDisplaySecs.
          }
        return true.
      }
  }

global function CreateNodeFromVec
  {
// Create a maneuver node from a delta-v vector.
// Notes:
//    - This code was copied from the Internet.
//    -
// Todo:
//    - This function needs to be checked and added to the code library.
//    -
    PARAMETER vec.
    parameter n_time IS TIME:SECONDS.

    LOCAL s_pro IS VELOCITYAT(SHIP,n_time):ORBIT.
    LOCAL s_pos IS POSITIONAT(SHIP,n_time)-ship:BODY:POSITION.
    LOCAL s_nrm IS VCRS(s_pro,s_pos).
    LOCAL s_rad IS VCRS(s_nrm,s_pro).

    LOCAL pro IS VDOT(vec,s_pro:NORMALIZED).
    LOCAL nrm IS VDOT(vec,s_nrm:NORMALIZED).
    LOCAL rad IS VDOT(vec,s_rad:NORMALIZED).

    RETURN NODE(n_time, rad, nrm, pro).
  }

global function DisplayDiagnosticMN
  {
// Display a KSP maneuver node as a diagnostic.
// Notes:
//    - The actual orbit will closely match this node
//      after the maneuver burn is done.
//    - Keep in mind running this diagnostic will
//      slow down the search, increasing the time
//      allowed for the search may be necessary.
//    - If you fiddle around with this code only display
//      a node for a short period of time then remove it
//      as a node on the flightpath of the ship affects the
//      orbit prediction commands such as positionat and
//      velocityat.
//    -
// Todo:
//    -
//
    parameter MNVec.
    parameter MNTStmp.

    set DiagnosticMN to CreateNodeFromVec(MNVec,MNTStmp).
    add DiagnosticMN.
    wait 1.
//    kuniverse:pause().
    remove DiagnosticMN.
    wait 0.
  }

global function DoSafeWait
  {
// A relatively reliable "Wait until a point in time" function
// that handles time warping.
// Notes:
//    - The KSP Time Warp is a "4th Wall" function as far as
//      kOS is concerned. Time Warp runs independently of kOS and can
//      respond to user input. Time Warp is not well synchronised
//      with kOS.
//    - This function tries to allow for various factors that
//      can affect how well kOS and Time Warp run together.
//    -
// Todo
//    - Test, test and test some more.
//    -

    parameter WaitToTStmp.
    parameter WarpTypeCode to "".   // NOWARP,PHYSICS,RAILS.

    if WarpTypeCode = "NOWARP"
      wait until timestamp() > WaitToTStmp.
    else
    if WarpTypeCode = "PHYSICS"
      {
        set kuniverse:timewarp:mode to WarpTypeCode.
        kuniverse:timewarp:warpTo(WaitToTStmp:seconds).
        wait until timestamp() > WaitToTStmp.
      }
    else
    if WarpTypeCode = "RAILS"
      {
// On-rails time warping only runs a limited game simulation,
// the ship is unpacked, some system values become undefined etc.
// The Player can also change the warp rate or stop the time warp completely.
// The "wait until" tries to get the time warp and the kOS script back into
// sync without issues.
        set kuniverse:timewarp:mode to WarpTypeCode.
        kuniverse:timewarp:warpTo(WaitToTStmp:seconds).
        wait until kuniverse:timewarp:warp = 0 and ship:unpacked.

// This "wait until" runs independently of the time warp.
// This wait will still work even if the time warp is modified by
// Player input.
// If the time warp stops early (undershoots) the wait duration will
// still be correct. If the time warp stops late (overshoots) then
// the wait duration will be longer than expected.
        wait until timestamp() > WaitToTStmp.
      }
    else
      print 0/0.  // Unknown WarpType value so terminate the script.
  }