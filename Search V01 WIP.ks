local function FineTuneBurnDeltav
  {
// Fine tune the calculated delta-v for the first burn.
// Notes:
//    - The objective is to get the apoapsis as close as possible
//      to the target orbit altitude by perturbating the delta-v
//      and recalculating the final orbit.
//      This will help compensate for errors caused by the departure
//      orbit not being exactly circular etc.
// Todo:
//    -

    parameter TargetAltitude.
    parameter ManeuverPointUT.
    parameter BallparkDeltav.

// Values to control how much searching is done.
    local MaxAttemps to 50.
    local DeltavIncrement to 0.01.

    local TestDeltav to 0.
    local FinalVelVec to 0.
    local finished to false.
    local attempts to 0.
    local TestOrbit to 0.
    local InitialPosVec to 0.
    local InitialVelVec to 0.
    local DebugFilename to "Hohmann Search "+kuniverse:realtime+".txt".

    set InitialPosVec to positionat(ship,ManeuverPointUT)-ship:body:position.
    set InitialVelVec to velocityat(ship,ManeuverPointUT):orbit.

    set TestDeltav to BallparkDeltav.
    set FinalVelVec to InitialVelVec+InitialVelVec:normalized*TestDeltav.
    set TestOrbit to
      createorbit
        (
          InitialPosVec,
          FinalVelVec,
          ship:body,
          ManeuverPointUT:seconds
        ).

    until finished
      {
        log TargetAltitude+" "+round(TestOrbit:apoapsis,3)+" "+round(TestDeltav,3) to DebugFilename.
        if NearEqual (TestOrbit:apoapsis,TargetAltitude,1000)
        or attempts > MaxAttemps
          set finished to true.
        else
        if TestOrbit:apoapsis < TargetAltitude
          {
            set TestDeltav to TestDeltav+DeltavIncrement.
          }
        else
          {
            set TestDeltav to TestDeltav-DeltavIncrement.
          }
        set FinalVelVec to InitialVelVec+InitialVelVec:normalized*TestDeltav.
        set TestOrbit to
          createorbit
            (
              InitialPosVec,
              FinalVelVec,
              ship:body,
              ManeuverPointUT:seconds
            ).
        set attempts to attempts+1.
      }
    return TestDeltav.
  }