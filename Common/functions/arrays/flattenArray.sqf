params ["_array"];

private _flattened = [];
{
    _flattened append _x;
} foreach _array;

_flattened