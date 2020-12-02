params [
    "_grid",
    "_position",
    "_maxRadius",
    "_countItemsToFind"
];

private _cellsPerRow = _grid getvariable "cellsPerRow";
private _cells = _grid getvariable "cells";

private _dX = 1;
private _dY = 0;
private _segmentLength = 0;

private _x = 0;
private _y = 0;
private _segmentPassed = 0;

private _totalCellCount = _cellsPerRow * _cellsPerRow;
private _result = [];

for "_i" from 0 to _totalCellCount do {
    _x = _x + _dX;
    _y = _y + _dY;

    if (_x > 0 && _x <= _cellsPerRow && _y > 0 && _y <= _cellsPerRow) then {
        private _cell = [_grid, [_x,_y]] call IVCS_Grid_coordsToCell;
        _result append _cell;
    };

    _segmentPassed = _segmentPassed + 1;

    if (_segmentPassed == _segmentLength) then {
        _segmentPassed = 0;

        private _buffer = _dX;
        _dX = -_dY;
        _dY = _buffer;

        if (_dY == 0) then {
            _segmentLength = _segmentLength + 1;
        };
    };
};

_result = _result apply { [(_x select 0) distance2D _position, _x] };
_result sort true;

_result select [0, _countItemsToFind]