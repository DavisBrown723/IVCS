params ["_location"];

private _type = if (_location isEqualType createHashMap) then { _location get "type" } else { _location getVariable "type" };
private _position = if (_location isEqualType createHashMap) then { _location get "position" } else { _location getVariable "position" };
private _size = if (_location isEqualType createHashMap) then { _location get "size" } else { _location getVariable "size" };

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