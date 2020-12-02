params ["_marker","_forceComposition"];

_forceComposition params ["_side","_faction","_totalGroupCount","_groupData"];

private _spawnPositions = [_marker, _totalGroupCount] call IVCS_Common_findRandomPositionsInMarker;
private _createdEntities = [];

{
    _x params ["_unitType","_groupCount","_groups"];

    {
        private _unitClasses = _x;
        private _spawnPos = _spawnPositions deleteat 0;

        _createdEntities pushback ([_unitClasses, _side, _faction, _spawnPos] call IVCS_VirtualSpace_createEntity);
    } foreach _groups;
} foreach _groupData;

_marker setmarkeralpha 0;

_createdEntities