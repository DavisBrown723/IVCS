params [
    "_opcom",
    "_position",
    "_entityCount",
    ["_unitTypes", ["group"]],
    ["_useIdleEntities", true]
]; // Do we need a max range parameter?

private _allEntities = if (_useIdleEntities) then {
    _opcom getvariable "idleEntities"
} else {
    _opcom getvariable "activeEntities"
};

private _entityPool = [];
{
    _entityPool append (_allEntities getvariable _x);
} foreach _unitTypes;

private _entitiesByDistance = _entityPool apply {
    private _entity = [_x] call IVCS_VirtualSpace_getEntity;
    private _entityPosition = _entity getvariable "position";

    [_entityPosition distance _position, _entity]
};

_entitiesByDistance sort true;

(_entitiesByDistance select [0, _entityCount]) apply { _x select 1 }