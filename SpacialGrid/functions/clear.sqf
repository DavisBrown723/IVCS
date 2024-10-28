params ["_grid"];

private _cells = _grid get "cells";
{
    _x resize 0;
} foreach _cells;