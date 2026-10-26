// Register before gameplay handlers. Repeated startup preserves the clock.
if (!isNil "IVCS_SimulationTime_FrameEH") exitWith {};
IVCS_SimulationTime = 0;
IVCS_SimulationPaused = isGamePaused;
IVCS_SimulationTime_LastTick = diag_tickTime;
IVCS_SimulationTime_FrameEH = addMissionEventHandler ["EachFrame", {
    [diag_tickTime,isGamePaused,accTime] call IVCS_Common_updateSimulationTime;
}];
