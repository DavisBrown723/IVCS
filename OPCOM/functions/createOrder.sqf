params ["_type"];

private _order = [] call CBA_fnc_createNamespace;
_order setvariable ["type", _type];

_order