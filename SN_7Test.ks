global isDryTest is false.
local targetAltitude is 10000.
global stableSeconds is 0.

global ForeAngle is 0.
global StarAngle is 0.
global TopAngle is 0.
global StarNorthAngle is 0.
global ForeAngleToVel is 0.

global pichSpeed is 0.

global RollDiff is 0.
global RollSpeed is 0.
global RightOffset is 0.
global LeftOffset is 0.

global YawDiff is 0.
global YawSpeed is 0.
global YawOffset is 0.

global padLAT is -0.09721.
global PadLNG is -74.55766.
global LATSpeed is 0.
global LATDiff is 0.
global PichNavCorrection is 0.

global LNGSpeed is 0.
global LNGDiff is 0.
global RollNavCorrection is 0.

global previousPitch is 0.
global previousRoll is 0.
global previousYaw is 0.
global previousLat is 0.
global previousLng is 0.

global TLFAngle is 0.
global TRFAngle is 0.
global BLFAngle is 0.
global BRFAngle is 0.


global TopFlapAngle is 0. 
global BottomFlapAngle is 0.

global MaxFlapAngle is 180.
global MinFlapAngle is 90.
global TopFlapAngleDefoult is 135.
global BottomFlapAngleDefoult is 135.
global TargetForAngle is 90.

global StageNo is 0.
global lastCount is 0.
global th is 0.

SET vess to SHIP.
global partlist is vess:PARTSNAMED("hinge.04").

until isDryTest = false{ // Set to TRUE if you want to run dry test on the ground.
    RCS ON.
    GetTelemetry().
    DrawVec().
    SetFlaps().  
    printComp(). 
}

/////////////////////////////////////////////////////////////////////////////
////////////////////////////////// STAGES ///////////////////////////////////
/////////////////////////////////////////////////////////////////////////////

stage.

until StageNo=1{
    // Ascent
    GetTelemetry().
    DrawVec().
    printComp().  
    
    LOCK STEERING TO Up + R((-LATDiff*100)+2,-LNGDiff*500,180).
    set th to 0.
    if (ship:altitude<targetAltitude/4){
        set th to 0.7.
    }else{
        set th to (targetAltitude - ship:altitude)/targetAltitude*0.15.
    }
    
    if ship:VERTICALSPEED<0{
        set th to th * ((ship:VERTICALSPEED * -1)*10).
    }
    
    lock throttle to th.           

    if ship:altitude> targetAltitude/2 and ship:VERTICALSPEED<5 and ship:VERTICALSPEED>-5{
                    
        set stableSeconds to stableSeconds + 1.
        if stableSeconds>5{
            set StageNo to StageNo + 1.
        }
    }           
}

until StageNo=2{ 
    // Flip to north  
    GetTelemetry().
    DrawVec().   
    printComp(). 
    SetFlaps().
    
    LOCK STEERING TO Up + R(-45,0,180).
    if (SHIP:FACING:PITCH<320 and SHIP:FACING:PITCH>180){
        lock throttle to 0.
        set StageNo to StageNo + 1.
    }else{
        lock throttle to 0.2.
    } 
}

until StageNo=3{
    // Descent    
    DrawVec().
    printComp().    
    GetTelemetry().
    SetFlaps().
    UNLOCK STEERING.
    if ship:altitude<680{
        set StageNo to StageNo + 1.
    }
}

until StageNo=4{
    // Fip to up
    DrawVec().
    printComp().    
    GetTelemetry().
    LOCK STEERING TO Up + R(0,0,180).

    partlist[2]:GETMODULE("ModuleRoboticServoHinge"):SETFIELD("Target Angle", MinFlapAngle).//bootom right
    partlist[3]:GETMODULE("ModuleRoboticServoHinge"):SETFIELD("Target Angle", MinFlapAngle).//bottom left

    partlist[1]:GETMODULE("ModuleRoboticServoHinge"):SETFIELD("Target Angle", MaxFlapAngle).//top right
    partlist[0]:GETMODULE("ModuleRoboticServoHinge"):SETFIELD("Target Angle", MaxFlapAngle).//top left

    if ForeAngle<20{
        set StageNo to StageNo + 1.
    }
}

until StageNo=5{
    // Land
    DrawVec().
    printComp().    
    GetTelemetry().
    LOCK STEERING TO SRFRETROGRADE.
    partlist[1]:GETMODULE("ModuleRoboticServoHinge"):SETFIELD("Target Angle", MinFlapAngle).//top right
    partlist[0]:GETMODULE("ModuleRoboticServoHinge"):SETFIELD("Target Angle", MinFlapAngle).//top left
    set th to 1 / (  100 /  -ship:VERTICALSPEED).
    if ship:altitude < 200{
        GEAR ON.
    partlist[2]:GETMODULE("ModuleRoboticServoHinge"):SETFIELD("Target Angle", MinFlapAngle+20).//bootom right
    partlist[3]:GETMODULE("ModuleRoboticServoHinge"):SETFIELD("Target Angle", MinFlapAngle+20).//bottom left
    }
    if ship:altitude < 105{
        set th to th + (-ship:VERTICALSPEED/15).
        LOCK STEERING TO Up + R(0,0,180).
    }
    LOCK throttle to th.
}



/////////////////////////////////////////////////////////////////////////////
/////////////////////////////// MY FUNCTIONS ////////////////////////////////
/////////////////////////////////////////////////////////////////////////////

function GetTopAngleToUP{
    return VANG(ship:facing:TOPVECTOR,ship:up:vector).
}
function GetStarAngleToUP{
    return VANG(ship:facing:STARVECTOR,ship:up:vector).
}
function GetForeAngleToUP{  
    return VANG(ship:facing:forevector,ship:up:vector).
}
function GetStarAngleToNORTH{  
    return VANG(ship:facing:STARVECTOR,ship:north:vector).
}
function GetForeAngleToVel{  
    return VANG(ship:facing:forevector,SHIP:VELOCITY:SURFACE).
}

function GetTelemetry{
    set LATDiff to padLAT - SHIP:GEOPOSITION:LAT.
    set LNGDiff to PadLNG - 0.001 - SHIP:GEOPOSITION:LNG.

    if (time:seconds-lastCount>0.1){
        set lastCount to  time:seconds.

        // LATSpeed
        set newLat to SHIP:GEOPOSITION:LAT.
        set LATSpeed to (previousLat - newLat).
        set previousLat to newLat.  
        
        // LNGSpeed
        set newLng to SHIP:GEOPOSITION:LNG.
        set LNGSpeed to (previousLng - newLng).
        set previousLng to newLng.  

        // PICH SPEED
        set newPitch to ForeAngle.
        set pichSpeed to (previousPitch - newPitch) * -1.
        set previousPitch to newPitch.  
        // ROLL SPEED
        set newRoll to StarAngle.
        set RollSpeed to (previousRoll - newRoll) * -1.
        set previousRoll to newRoll.  
        // YAW SPEED        
        set newYaw to StarNorthAngle.
        set YawSpeed to (previousYaw - newYaw) * -1.
        set previousYaw to newYaw.                             
    }

    set ForeAngle to GetForeAngleToUP().
    set StarAngle to GetStarAngleToUP().
    set TopAngle to GetTopAngleToUP().
    set StarNorthAngle to GetStarAngleToNORTH().
    set ForeAngleToVel to GetForeAngleToVel().
}

function SetFlaps{

    /////////////////////////////////////////////////////
    // -- PICH
    local PitchReactionMultiFactor is 1.
    local PitchBreakMultiFactor is 20.
    
    set TopFlapAngle to TopFlapAngleDefoult + (ForeAngle-TargetForAngle)* PitchReactionMultiFactor.
    set BottomFlapAngle to BottomFlapAngleDefoult - (ForeAngle-TargetForAngle)* PitchReactionMultiFactor.
    
    if (TopFlapAngle>MaxFlapAngle){
        set TopFlapAngle to MaxFlapAngle.
    }
    if (TopFlapAngle<MinFlapAngle){
        set TopFlapAngle to MinFlapAngle.
    }
    if (BottomFlapAngle>MaxFlapAngle){
        set BottomFlapAngle to MaxFlapAngle.
    }
    if (BottomFlapAngle<MinFlapAngle){
        set BottomFlapAngle to MinFlapAngle.
    }
    // -- PichNavCorrection
    local max is 11.
    local LATOffset is 0.00462. // Requaire offset of LAT for flipp from horizontal to vertical
    set PichNavCorrection to (LATDiff + LATOffset) * 3000.
        if (PichNavCorrection>max){
            set PichNavCorrection to max.
        }
        if (PichNavCorrection <-max){
            set PichNavCorrection to -max.
    }
    
    /////////////////////////////////////////////////////
    // -- ROLL
    local RollReactionMultiFactor is 0.5.
    local RollBreakMultiFactor is 1.0.    

    if(TopAngle<90){//roof points to up
        set RollDiff to StarAngle - 90 .
    }else{
        if(StarAngle>90){//roof poitns to ground
            set RollDiff to TopAngle.
        }else{
            set RollDiff to TopAngle * -1.
        }
    }
    // RollNavCorrection
    set RollNavCorrection to LNGDiff * 5000 + (LNGSpeed/10).
    if (RollNavCorrection >11){
        set RollNavCorrection to 11.
    }
    set RollDiff to RollDiff + RollNavCorrection.

    if (RollDiff<0){//lean to left
        set RightOffset to RollDiff * RollReactionMultiFactor + RollSpeed * RollBreakMultiFactor.
        set LeftOffset to 0.
    }else{//lean to right
        set LeftOffset to RollDiff * -1 * RollReactionMultiFactor - RollSpeed * RollBreakMultiFactor.
        set RightOffset to 0.
    }

    /////////////////////////////////////////////////////
    // -- YAW
    local YawReactionMultiFactor is 0.3.
    local YawBreakMultiFactor is 0.3.

    if(VANG(ship:facing:forevector,NORTH:vector)<90){//star vector points to east
        set YawDiff to StarNorthAngle - 90.
    }else{//star vector points to west
        if(StarNorthAngle>90){
            set YawDiff to VANG(ship:facing:forevector,NORTH:vector).
        }else{
            set YawDiff to VANG(ship:facing:forevector,NORTH:vector) * -1.
        }
    }
    set YawOffset to YawDiff * YawReactionMultiFactor + YawSpeed*YawBreakMultiFactor + YawSpeed.

    

    ///////////////////////////////////////////////////
    ///////////////////////////////////////// SET FLAPS
    ///////////////////////////////////////////////////


    set TLFAngle to TopFlapAngle + PichNavCorrection + LeftOffset + pichSpeed * PitchBreakMultiFactor + YawOffset.
    set TRFAngle to TopFlapAngle + PichNavCorrection + RightOffset + pichSpeed * PitchBreakMultiFactor - YawOffset.
    set BLFAngle to BottomFlapAngle + LeftOffset - pichSpeed * PitchBreakMultiFactor - YawOffset.
    set BRFAngle to BottomFlapAngle + RightOffset - pichSpeed * PitchBreakMultiFactor + YawOffset.

    //Limit flaps angle
    if (TLFAngle>MaxFlapAngle){
        set TLFAngle to MaxFlapAngle.
    }else if (TLFAngle<MinFlapAngle){
        set TLFAngle to MinFlapAngle.
    }
    if (TRFAngle>MaxFlapAngle){
        set TRFAngle to MaxFlapAngle.
    }else if (TRFAngle<MinFlapAngle){
        set TRFAngle to MinFlapAngle.
    }
    if (BLFAngle>MaxFlapAngle){
        set BLFAngle to MaxFlapAngle.
    }else if (BLFAngle<MinFlapAngle){
        set BLFAngle to MinFlapAngle.
    }
    if (BRFAngle>MaxFlapAngle){
        set BRFAngle to MaxFlapAngle.
    }else if (BRFAngle<MinFlapAngle){
        set BRFAngle to MinFlapAngle.
    }

    partlist[1]:GETMODULE("ModuleRoboticServoHinge"):SETFIELD("Target Angle", TRFAngle).//top right
    partlist[0]:GETMODULE("ModuleRoboticServoHinge"):SETFIELD("Target Angle", TLFAngle).//top left

    partlist[2]:GETMODULE("ModuleRoboticServoHinge"):SETFIELD("Target Angle", BRFAngle).//bootom right
    partlist[3]:GETMODULE("ModuleRoboticServoHinge"):SETFIELD("Target Angle", BLFAngle).//bottom left

    // Adjust TargetForAngle to keep velocity vector close to vertical as posible.
    if(isDryTest = false){
        if (ForeAngleToVel < 90){
            set TargetForAngle to TargetForAngle-0.5.
        }else{
            set TargetForAngle to TargetForAngle+0.5.
        } 
    }
}.



function printComp{
    clearscreen.
    print "isDryTest            |" + isDryTest.
    print "StageNo:             |" + StageNo.
    print "ship:VERTICALSPEED   |" + ship:VERTICALSPEED.
    print "ForeAngle            |" + ForeAngle.    
    print "TopAngle             |" + TopAngle. 
    print "StarAngle            |" + StarAngle.
    print "StarNorthAngle       |" + StarNorthAngle.
    print "----------------PICH--------------------".
    print "TopFlapAngle         |" + TopFlapAngle.    
    print "BottomFlapAngle      |" + BottomFlapAngle.    
    print "pichSpeed            |" + pichSpeed.
    print "ForeAngleToVel       |" + ForeAngleToVel.
    print "TargetForAngle       |" + TargetForAngle.
    print "----------------ROLL--------------------".
    print "RollDiff             |" + RollDiff.
    print "RollSpeed            |" + RollSpeed.
    print "RightOffset          |" + RightOffset.
    print "LeftOffset           |" + LeftOffset.
    print "----------------YAW---------------------".
    print "YawDiff              |" + YawDiff.
    print "YawSpeed             |" + YawSpeed.
    print "YawOffset            |" + YawOffset.
    print "---------NAVIGATION---------------------".
    print "-----------------LAT--------------------".
    print "LAT                  |" + SHIP:GEOPOSITION:LAT.
    print "LATDiff              |" + LATDiff.
    print "LATSpeed             |" + LATSpeed.
    print "PichNavCorrection    |" + PichNavCorrection.
    print "-----------------LNG--------------------".
    print "LNG                  |" + SHIP:GEOPOSITION:LNG.
    print "LNGDiff              |" + LNGDiff.
    print "LNGSpeed             |" + LNGSpeed.
    print "RollNavCorrection    |" + RollNavCorrection.
    print "----------------------------------------".
    print "-------------FLAPS----------------------".
    print "TLFAngle             |" + TLFAngle.
    print "TRFAngle             |" + TRFAngle.
    print "BLFAngle             |" + BLFAngle.
    print "BRFAngle             |" + BRFAngle.    
    wait 0.05. 
}.

function DrawVec{
        
    SET anArrow TO VECDRAW(
      V(0,0,0),
      SHIP:FACING:vector,
      RGB(1,0,0),
      "",
      20.0,
      TRUE,
      0.005,
      TRUE,
      TRUE
    ).

    SET anArrow2 TO VECDRAW(
      V(0,0,0),
      SHIP:UP:vector,
      RGB(0,1,0),
      "",
      20.0,
      TRUE,
      0.005,
      TRUE,
      TRUE
    ).

    SET anArrow3 TO VECDRAW(
      V(0,0,0),
      SHIP:VELOCITY:SURFACE,
      RGB(0,0,1),
      "",
      1.0,
      TRUE,
      0.5,
      TRUE,
      TRUE
    ).

    SET anArrow4 TO VECDRAW(
      V(0,0,0),
      SHIP:FACING:UPVECTOR,
      RGB(1,0.5,0.5),
      "",
      20.0,
      TRUE,
      0.005,
      TRUE,
      TRUE
    ).
    
    SET anArrow5 TO VECDRAW(
      V(0,0,0),
      SHIP:FACING:STARVECTOR,
      RGB(0,1,1),
      "",
      20.0,
      TRUE,
      0.005,
      TRUE,
      TRUE
    ).
}.

