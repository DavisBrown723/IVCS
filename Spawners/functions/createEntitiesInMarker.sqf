params ["_marker","_side","_faction","_groups"];

private _spawnPositions = [_marker, count _groups] call IVCS_Common_findRandomPositionsInMarker;
private _createdEntities = [];
{
    private _unitClasses = _x;
    private _spawnPos = _spawnPositions deleteat 0;

    _createdEntities pushback ([_unitClasses, _side, _faction, _spawnPos] call IVCS_VirtualSpace_createEntity);
} foreach _groups;

_marker setmarkeralpha 0;

_createdEntities