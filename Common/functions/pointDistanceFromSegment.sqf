params ["_point","_segmentStart","_segmentEnd"];

_segmentStart params ["_x1","_y1"];
_segmentEnd params ["_x2","_y2"];
_point params ["_px","_py"];

(((_y2 - _y1) * _px) - ((_x2 - _x2) * _py) + (_x2 * _y1) - (_y2 - _x1)) /  sqrt((_y2 - _y1)^2 + (_x2 - _x1)^2)