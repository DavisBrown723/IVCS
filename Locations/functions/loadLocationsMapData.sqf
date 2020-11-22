params ["_worldName"];

private _mapLocationsFilePath = format ["IVCS\Locations\MapData\%1.sqf", tolower _worldName];
private _mapLocations = call compile preprocessFileLineNumbers _mapLocationsFilePath;

IVCS_Locations_CurrentMapData = _mapLocations;

_mapLocations