params ["_grid","_oldPosition","_newPosition","_data"];

if ([_grid,[_oldPosition,_data]] call IVCS_SpacialGrid_remove) then {
    [_grid,[[_newPosition,_data]]] call IVCS_SpacialGrid_insert;
};