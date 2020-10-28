params ["_unitClass"];

private _unit = [] call CBA_fnc_createNamespace;
_unit setvariable ["id", ""];
_unit setvariable ["class", _unitClass];
_unit setvariable ["object", objnull];
_unit setvariable ["damage", 0];
_unit setvariable ["vehicleAssignment", []];

_unit