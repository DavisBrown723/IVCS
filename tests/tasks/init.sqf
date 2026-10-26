if (isServer) then {
    call compile preprocessFileLineNumbers "IVCS\initFunctions.sqf";
    [] call IVCS_Common_startSimulationClock;
    [] spawn compile preprocessFileLineNumbers "test.sqf";
};
