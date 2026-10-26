// Clockwise rectangle corners, used for compatibility bounds and review exports.
params ["_footprint"];
if (_footprint isEqualTo [] || {(_footprint select 0) != "rectangle"}) exitWith { [] };
_footprint params ["_shape", "_center", "_axes", "_angle"];
[[-1,-1],[-1,1],[1,1],[1,-1]] apply {
    private _localX = (_x select 0) * (_axes select 0);
    private _localY = (_x select 1) * (_axes select 1);
    [(_center select 0) + _localX * cos _angle + _localY * sin _angle, (_center select 1) - _localX * sin _angle + _localY * cos _angle, 0]
}
