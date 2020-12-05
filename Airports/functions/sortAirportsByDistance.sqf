params ["_position"];

private _airports = [] call IVCS_Airports_getAllAirports;
private _airportsByDistance = _airports apply { [(_x select 1) distance2D _position, _x] };
_airportsByDistance sort true;

_airportsByDistance apply { _x select 1 };