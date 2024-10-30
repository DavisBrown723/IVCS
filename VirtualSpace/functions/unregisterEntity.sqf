params ["_entity"];

// remove from registry so profile appears
// dead in subsequent scripts

private _entityID = _entity get "id";

["IVCS_VirtualSpace_entityUnregistered", _entity] call CBA_fnc_localEvent;

private _entitiesSpacialGrid = IVCS_VirtualSpace_Controller get "entitiesSpacialGrid";
[_entitiesSpacialGrid, [_entity get "position", _entity]] call IVCS_SpacialGrid_remove;

private _entities = IVCS_VirtualSpace_Controller get "entities";
private _allEntities = _entities get "ALL";
_allEntities set [_entityID, nil];

// cleanup entity data

private _onUnregisterFunc = _entity get "unregister";
call (missionnamespace getvariable _onUnregisterFunc);