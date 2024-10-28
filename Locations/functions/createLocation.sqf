params ["_type","_position","_size"];

/*
    Types:
    town
    fuel
    power
    airfield
    base
*/

private _location = createHashMapFromArray [
    ["type", _type],
    ["position", _position],
    ["size", _size]
];

_location