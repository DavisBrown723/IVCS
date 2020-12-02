params [
    "_grid",
    "_position",
    "_radius",
    ["_check2D", true],
    ["_returnItem", true]
];

private _lowerLeft = [(_position select 0) - _radius, (_position select 1) - _radius];
private _upperRight = [(_position select 0) + _radius, (_position select 1) + _radius];

private _minCoords = [_grid, _lowerLeft, true] call IVCS_SpacialGrid_positionToCoords;
private _maxCoords = [_grid, _upperRight, true] call IVCS_SpacialGrid_positionToCoords;

private _cellsPerRow = _grid getvariable "cellsPerRow";

_minCoords = _minCoords apply {_x max 0};
_maxCoords = _maxCoords apply {_x min (_cellsPerRow - 1)};

private _cells = _grid getvariable "cells";
private _result = [];

for "_y" from (_minCoords select 1) to (_maxCoords select 1) do {
    for "_x" from (_minCoords select 0) to (_maxCoords select 0) do {
        private _index = _x + (_y * _cellsPerRow);
        _result append (_cells select _index);
    };
};

if (!_check2D) then {
    _result = _result select { ((_x select 0) distance _position) <= _radius };
} else {
    _result = _result select { ((_x select 0) distance2D _position) <= _radius };
};

if (_returnItem) then {
    _result = _result apply {_x select 1};
};

_result