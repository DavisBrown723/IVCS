params ["_entity"];

// remove from registry so profile appears
// dead in subsequent scripts

private _entityID = _entity get "id";
private _entities = IVCS_VirtualSpace_Controller get "entities";
private _allEntities = _entities get "ALL";
if !(_entityID in _allEntities) exitWith {};

private _entitiesSpacialGrid = IVCS_VirtualSpace_Controller get "entitiesSpacialGrid";
[_entitiesSpacialGrid, [_entity get "position", _entity]] call IVCS_SpacialGrid_remove;

_allEntities deleteat _entityID;
private _stateIDs = _entities get (if (_entity get "active") then { "active" } else { "inactive" });
private _index = _stateIDs find _entityID;
if (_index != -1) then { _stateIDs deleteAt _index; };
// cleanup entity data

private _onUnregisterFunc = _entity get "unregister";
[_entity] call (missionnamespace getvariable _onUnregisterFunc);