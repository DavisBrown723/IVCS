params ["_grid", "_oldPosition", "_newPosition", "_data"];

[_grid, [_oldPosition, _data]] call IVCS_SpacialGrid_remove;
// An entity can enter the grid after starting or moving outside its bounds.
[_grid, [[_newPosition, _data]]] call IVCS_SpacialGrid_insert;
