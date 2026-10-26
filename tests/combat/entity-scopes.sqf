// Diagnostic-only entity stage scopes; inclusive parents contain helper costs.
{
    private _saved="IVCS_EntityDiag_"+_x;
    missionNamespace setVariable [_saved,missionNamespace getVariable _x];
    missionNamespace setVariable [_x,compile format ['private _scope=createProfileScope %1; _this call %2',str ("IVCS_ENTITY_"+_x),_saved]];
} forEach [
    "IVCS_VirtualSpace_Group_update","IVCS_VirtualSpace_Vehicle_update",
    "IVCS_VirtualSpace_setEntityPosition","IVCS_SpacialGrid_move",
    "IVCS_EntityTasks_syncActiveTask","IVCS_VirtualSpace_getCurrentEntityTask",
    "IVCS_Combat_isInfantry","IVCS_Combat_mountState","IVCS_Combat_getWeaponProfile",
    "IVCS_Combat_getVehicleProfile","IVCS_Combat_getHelicopterPolicy",
    "IVCS_Combat_getHelicopterAttackArea","IVCS_Combat_releaseHelicopterMovement",
    "IVCS_VirtualSpace_getEntity","IVCS_VirtualSpace_getEntityCurrentWaypoint"
];
diag_log "[IVCS PERF] ENTITY_SCOPES installed";
