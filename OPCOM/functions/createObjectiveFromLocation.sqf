params ["_location"];

private _type = _location getvariable "type";
private _position = _location getvariable "position";
private _size = _location getvariable "size";

private _objective = [] call CBA_fnc_createNamespace;
_objective setvariable ["id", ""];
_objective setvariable ["position", _position];
_objective setvariable ["size", _size];
_objective setvariable ["type", _type];
_objective setvariable ["priority", -1];
_objective setvariable ["debugMarker", ""];
_objective setvariable ["controlState", "unknown"];
_objective setvariable ["orders", []];
_objective setvariable ["timeLastScanned", -999];

_objective