// Legacy weapon-loadout interface; complete magazine inventory lives in Common.
params ["_unitClass"];
([_unitClass] call IVCS_Common_getUnitLoadoutInfo) apply {
    [_x select 0, (_x select 1) apply { _x select [0, 2] }]
}
