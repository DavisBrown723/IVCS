params ["_locations","_forceComposition"];

_forceComposition params ["_side","_faction","_totalGroupCount","_groupData"];

// #TODO: sort by objective priority
// so high prio areas get leftover units first
// airfield -> base -> town -> settlement
_locations = _locations call BIS_fnc_arrayShuffle;

// figure out how many units of each type
// should be put at each location

private _locationCount = count _locations;
private _locationGroupAssignments = _locations apply { [_x, []] };

{
    _x params ["_unitType","_groupCount","_groups"];

    // shuffle locations each time we switch unit type to avoid
    // having the same objectives get unit leftovers each time
    _locationGroupAssignments = _locationGroupAssignments call BIS_fnc_arrayShuffle;

    private _countPerLocation = floor (_groupCount / _locationCount) max 1;

    private _countLeftToPlace = _groupCount;
    private _locationIter = 0;
    while {_countLeftToPlace > 0} do {
        private _locationGroupAssignment = _locationGroupAssignments select _locationIter;
        private _groupsToAdd = _groups select [_groupCount - _countLeftToPlace, _countPerLocation];

        _countLeftToPlace = _countLeftToPlace - (count _groupsToAdd);

        (_locationGroupAssignment select 1) append _groupsToAdd;

        if (_countLeftToPlace > 0) then {
            _locationIter = _locationIter + 1;
            if (_locationIter == _locationCount) then {
                _locationIter = 0;
            };
        };
    };
} foreach _groupData;

private _createdEntities = [];
{
    _x params ["_location","_groupsToPlace"];
    private _locationPosition = _location get "position";
    private _locationSize = _location get "size";
    private _spawnPositions = [_locationPosition, _locationSize, count _groupsToPlace] call IVCS_Common_generateRandomPositionsInRadius;

    {
        private _entities = [_x,_side,_faction, _spawnPositions deleteat 0] call IVCS_VirtualSpace_createEntity;
        _createdEntities pushback _entities;
    } foreach _groupsToPlace;
} foreach _locationGroupAssignments;

_createdEntities