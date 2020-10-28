params ["_entity"];

// remove from registry so profile appears
// dead in subsequent scripts

private _entityID = _entity getvariable "id";

private _entities = IVCS_VirtualSpace_Controller getvariable "entities";
private _allEntities = _entities getvariable "all";
_allEntities setvariable [_entityID, nil];

// cleanup entity data

private _onUnregisterFunc = _entity getvariable "unregister";

call (missionnamespace getvariable _onUnregisterFunc);

_entity call CBA_fnc_deleteNamespace;