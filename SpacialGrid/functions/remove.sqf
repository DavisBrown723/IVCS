params ["_grid", "_item"];

_item params ["_position", "_data"];
private _coords = [_grid, _position] call IVCS_SpacialGrid_positionToCoords;
if (_coords isEqualTo [-1, -1]) exitWith { false };

private _cell = [_grid, _coords] call IVCS_SpacialGrid_coordsToCell;
private _index = _cell find _item;
if (_index == -1) exitWith { false };
_cell deleteAt _index;

true
