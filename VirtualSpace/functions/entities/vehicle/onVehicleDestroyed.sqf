params ["_unit", "_killer", "_instigator", "_useEffects"];

private _entityID = _unit getvariable "entityID";
if (!isnil "_entityID") then {
    private _entity = [_entityID] call IVCS_VirtualSpace_getEntity;
    [_entity] call IVCS_VirtualSpace_unregisterEntity;
};