params ["_grid","_items"];

{
    _x params ["_position","_data"];

    private _coords = [_grid,_position] call IVCS_SpacialGrid_positionToCoords;

    if !(_coords isequalto [-1,-1]) then {
        private _cell = [_grid,_coords] call IVCS_SpacialGrid_coordsToCell;
        _cell pushback _x;
    };
} foreach _items;