params ["_type","_position","_size"];

private _location = [] call CBA_fnc_createNamespace;
_location setvariable ["type", _type];
_location setvariable ["position", _position];
_location setvariable ["size", _size];

_location