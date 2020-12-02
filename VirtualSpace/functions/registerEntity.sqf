params ["_entity"];

private _entityType = _entity getvariable "entityType";

private _groups = IVCS_VirtualSpace_Controller getvariable "entities";
private _allEntities = _groups getvariable "all";

private _nextEntityIDNum = IVCS_VirtualSpace_Controller getvariable "nextEntityID";
IVCS_VirtualSpace_Controller setvariable ["nextEntityID", _nextEntityIDNum + 1];

private _entityID = format ["e_%1", _nextEntityIDNum];
_allEntities setvariable [_entityID, _entity];

_entity setvariable ["id", _entityID];

private _entitiesSpacialGrid = IVCS_VirtualSpace_Controller getvariable "entitiesSpacialGrid";
[_entitiesSpacialGrid, [[_entity getvariable "position", _entity]]] call IVCS_SpacialGrid_insert;

_entityID