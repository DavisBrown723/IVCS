// Initialize on every machine before registering gameplay frame handlers.
[] call IVCS_Common_startSimulationClock;
if (isserver) then {
    call compile preprocessFileLineNumbers "IVCS\Common\startup.sqf";
    call compile preprocessFileLineNumbers "IVCS\Execution\startup.sqf";
    //call compile preprocessFileLineNumbers "IVCS\Airports\startup.sqf";
    call compile preprocessFileLineNumbers "IVCS\EntityTasks\startup.sqf";
    call compile preprocessFileLineNumbers "IVCS\VirtualSpace\startup.sqf";
    call compile preprocessFileLineNumbers "IVCS\Paths\startup.sqf";
    call compile preprocessFileLineNumbers "IVCS\Factions\startup.sqf";
    //call compile preprocessFileLineNumbers "IVCS\Locations\startup.sqf";
    //call compile preprocessFileLineNumbers "IVCS\OPCOM\startup.sqf";
};