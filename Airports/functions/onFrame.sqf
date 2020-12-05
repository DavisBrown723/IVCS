if (diag_tickTime - IVCS_Airports_TimeLastCheck < 30) exitwith {};

private _dynamicAirports = allAirports select 1;

{
    private _airportID = 100 + _foreachindex;
    private _existingAirport = [_airportID] call IVCS_Airports_getAirport;
    if (isnil "_existingAirport") then {
        [_airportID] call IVCS_Airports_registerAirport;
    };
} foreach _dynamicAirports;

IVCS_Airports_TimeLastCheck = diag_tickTime;