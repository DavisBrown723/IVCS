IVCS_Airports = [] call CBA_fnc_createNamespace;

private _startingAirports = allAirports;
{
    [_x] call IVCS_Airports_registerAirport;
} foreach ((_startingAirports select 0) + (_startingAirports select 1));

IVCS_Airports_TimeLastCheck = diag_tickTime;

private _frameEventHandler = addMissionEventHandler ["EachFrame", IVCS_Airports_onFrame];
IVCS_Airports_OnFrameEH = _frameEventHandler;