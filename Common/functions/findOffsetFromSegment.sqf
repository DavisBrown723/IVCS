params ["_segmentPoint1","_segmentPoint2","_point"];

_segmentPoint1 params ["_segmentPoint1X","_segmentPoint1Y"];

/*
    _offset < 0  Point lies left of the segment
    _offset > 0  Point lies right of the segment
    _offset == 0  Point lies on the segment
*/

private _offset = (((_point select 1) - _segmentPoint1Y) * ((_segmentPoint2 select 0) - _segmentPoint1X))
-
(((_segmentPoint2 select 1) - _segmentPoint1Y) * ((_point select 0) - _segmentPoint1X));

if (_offset < 0) then {
    -1
} else {
    if (_offset > 0) then {
        1
    } else {
        0
    };
};