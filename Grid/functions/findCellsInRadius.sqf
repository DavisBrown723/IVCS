params ["_grid","_position","_radius"];

private _lowerLeft = [(_position select 0) - _radius, (_position select 1) - _radius];
private _upperRight = [(_position select 0) + _radius, (_position select 1) + _radius];

private _minCoords = [_grid, _lowerLeft, true] call IVCS_SpacialGrid_positionToCoords;
private _maxCoords = [_grid, _upperRight, true] call IVCS_SpacialGrid_positionToCoords;

private _cellsPerRow = _grid get "cellsPerRow";

_minCoords = _minCoords apply {_x max 0};
_maxCoords = _maxCoords apply {_x min (_cellsPerRow - 1)};

private _cells = _grid get "cells";
private _cellsInRadius = [];

for "_y" from (_minCoords select 1) to (_maxCoords select 1) do {
    for "_x" from (_minCoords select 0) to (_maxCoords select 0) do {
        private _index = _x + (_y * _cellsPerRow);
        _cellsInRadius append (_cells select _index);
    };
};

_cellsInRadius