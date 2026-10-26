// Shortest 2D distance to the filled footprint, zero inside. No engine marker needed.
params ["_footprint", "_position"];
if (_footprint isEqualTo []) exitWith { 1e30 };
_footprint params ["_shape", "_center", "_axes", "_angle"];
if (_shape == "circle") exitWith { ((_position distance2D _center) - (_axes select 0)) max 0 };
private _dx = (_position select 0) - (_center select 0);
private _dy = (_position select 1) - (_center select 1);
private _outsideX = (abs (_dx * cos _angle - _dy * sin _angle) - (_axes select 0)) max 0;
private _outsideY = (abs (_dx * sin _angle + _dy * cos _angle) - (_axes select 1)) max 0;
sqrt (_outsideX * _outsideX + _outsideY * _outsideY)
