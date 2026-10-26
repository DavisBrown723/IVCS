params ["_unit", "_killer", "_instigator", "_useEffects"];

private _entityID = _unit getvariable "entityID";
if (!isnil "_entityID") then {
    private _entity = [_entityID] call IVCS_VirtualSpace_getEntity;
    if (!isNil "_entity") then {
        private _nativeGroups = (_entity get "nativeCrew") apply { group _x };
        { deleteVehicle _x; } forEach (_entity get "nativeCrew");
        (_entity get "nativeCrew") resize 0;
        { deleteGroup _x; } forEach (_nativeGroups arrayIntersect _nativeGroups);
        [_entity] call IVCS_VirtualSpace_unregisterEntity;
    };
};