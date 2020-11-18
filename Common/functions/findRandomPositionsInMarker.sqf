params ["_marker","_positionCount"];

private _positions=  [];
for "_i" from 0 to _positionCount - 1 do {
    _positions pushback (_marker call BIS_fnc_randomPosTrigger);
};

_positions