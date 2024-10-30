params ["_entity"];

private _entityType = _entity get "entityType";

private _entities = IVCS_VirtualSpace_Controller get "entities";
private _allEntities = _entities get "ALL";

private _nextEntityIDNum = IVCS_VirtualSpace_Controller get "nextEntityID";
IVCS_VirtualSpace_Controller set ["nextEntityID", _nextEntityIDNum + 1];

private _entityID = format ["e_%1", _nextEntityIDNum];
_allEntities set [_entityID, _entity];

_entity set ["id", _entityID];

private _entitiesSpacialGrid = IVCS_VirtualSpace_Controller get "entitiesSpacialGrid";
[_entitiesSpacialGrid, [[_entity get "position", _entity]]] call IVCS_SpacialGrid_insert;

_entityID