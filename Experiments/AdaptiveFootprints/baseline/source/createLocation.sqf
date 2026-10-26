params ["_type","_position","_size"];

/*
    Types:
    town
    fuel
    power
    airfield
    base
    radiotower
    port
    factory
    hospital
*/

private _location = createHashMapFromArray [
    ["type", _type],
    ["position", _position],
    ["size", _size]
];

_location