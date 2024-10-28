params ["_location","_side","_faction","_groups"];

private _locationCenter = _location get "position";
private _locationSize = _location get "size";

private _spawnPositions = [_locationCenter, _locationSize, count _groups] call IVCS_Common_generateRandomPositionsInRadius;
private _createdEntities = [];

{
    private _unitClasses = _x;
    if (_unitClasses isequaltype configNull) then {
        _unitClasses = [_unitClasses] call IVCS_Common_getUnitClassesFromGroupConfig;
        private _spawnPos = _spawnPositions deleteat 0;

        _createdEntities pushback ([_unitClasses, _side, _faction, _spawnPos] call IVCS_VirtualSpace_createEntity);
    };
} foreach _groups;

_createdEntities