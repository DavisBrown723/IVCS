params ["_shapePoints","_testPoint"];

// _shapePoints should be in order

private _inShape = true;

private _dir = [_shapePoints select 0, _shapePoints select 1, _testPoint] call IVCS_Common_findOffsetFromSegment;
for "_i" from 1 to (count _shapePoints - 2) do {
    private _thisSegmentDir = [_shapePoints select _i, _shapePoints select (_i + 1), _testPoint] call IVCS_Common_findOffsetFromSegment;

    if (_thisSegmentDir != _dir) exitwith {
        _inShape = false;
    };
};

_inShape