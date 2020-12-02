params ["_grid","_item"];

_item params ["_position","_data"];

private _coords = [_grid,_position] call IVCS_SpacialGrid_positionToCoords;

if !(_coords isequalto [-1,-1]) then {
    private _cell = [_grid,_coords] call IVCS_SpacialGrid_coordsToCell;
    _cell deleteat (_cell find _item);
    
    true
} else {
    false
};