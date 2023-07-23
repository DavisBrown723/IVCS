params ["_point","_segmentStart","_segmentEnd"];

_segmentStart params ["_x1","_y1"];
_segmentEnd params ["_x2","_y2"];
_point params ["_x0","_y0"];

(abs (((_y1 - _y2) * _x0) + ((_x2 - _x1) * _y0) + (_x1 * _y2) - (_x2 * _y1))) / (_segmentStart distance2D _segmentEnd)