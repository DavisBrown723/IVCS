params ["_grid"];

private _cells = _grid getvariable "cells";
{
    _x resize 0;
} foreach _cells;