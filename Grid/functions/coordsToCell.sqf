params ["_grid","_coords"];

if !(_coords isequalto [-1,-1]) then {
    private _cellsPerRow = _grid getvariable "cellsPerRow";
    private _cells = _grid getvariable "cells";
    private _index = (_coords select 0) + ((_coords select 1) * _cellsPerRow);
    _cells select _index
};