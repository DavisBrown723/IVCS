// Diagnostic: reproduce a dry rifle at virtual-to-native handoff, at 1x.
waitUntil { time > 0 };
call compile preprocessFileLineNumbers "IVCS\initFunctions.sqf";
call compile preprocessFileLineNumbers "IVCS\EntityTasks\startup.sqf";
IVCS_Common_WeaponInfo = createHashMap; IVCS_Common_MagazineInfo = createHashMap;
IVCS_Common_AmmoInfo = createHashMap; IVCS_Common_UnitInfo = createHashMap;
IVCS_Common_WeaponAliases = createHashMap;
IVCS_Paths_Generator = createHashMapFromArray [["requestQueue",[]],["currentRequest",[]]];
IVCS_VirtualSpace_Controller = [false] call IVCS_VirtualSpace_createController;
removeMissionEventHandler ["EachFrame",IVCS_VirtualSpace_Controller get "onFrameHandlerID"];
IVCS_Probe_OriginalCreateRequest = IVCS_Ammo_createRequest;
IVCS_Ammo_createRequest = {
    private _recipient = _this select 1;
    _recipient set ["probeAttempts",(_recipient getOrDefault ["probeAttempts",0]) + 1];
    _this call IVCS_Probe_OriginalCreateRequest;
};
{
    _x params ["_class","_extraEmpties"];
    private _r = [_class,"u_0"] call IVCS_VirtualSpace_Group_createUnit;
    private _d = ["B_Soldier_A_F","u_1"] call IVCS_VirtualSpace_Group_createUnit;
    private _entity = ["WEST","BLU_F",[14500,16400,0],[_r,_d]] call IVCS_VirtualSpace_Group_createEntity;
    private _rifle = ((_r get "weapons") select { (([_x select 0] call IVCS_Ammo_getWeaponProfile) select 0) == 1 }) select 0;
    { _x set [1,0]; } forEach (_rifle select 1);
    for "_i" from 1 to _extraEmpties do { (_rifle select 1) pushBack ["30Rnd_65x39_caseless_mag",0,[]]; };
    diag_log format ["[IVCS AMMO PROBE] VIRTUAL class=%1 magazines=%2",_class,_r get "weapons"];
    [_entity] call IVCS_VirtualSpace_Group_spawn;
    private _object = _r get "object";
    { private _o = _x get "object"; _o disableAI "TARGET"; _o disableAI "AUTOTARGET"; _o disableAI "MOVE"; _o allowDamage false; } forEach [_r,_d];
    _object setPosATL [14500,16400,0]; (_d get "object") setPosATL [14500.5,16400,0];
    private _started = diag_tickTime; private _last = "";
    while { diag_tickTime - _started < 16 && { (_object ammo primaryWeapon _object) == 0 || { (_entity get "ammoRequests") isNotEqualTo [] } } } do {
        [_entity,IVCS_SimulationTime,false] call IVCS_Ammo_updateGroup;
        private _state = str [(_entity get "ammoRequests") apply { [_x get "phase",_x get "weapon"] },_entity get "ammoTransfers",_r getOrDefault ["probeAttempts",0],weaponState _object,_object canAdd "30Rnd_65x39_caseless_mag"];
        if (_state != _last) then { diag_log format ["[IVCS AMMO PROBE] STATE class=%1 extra=%2 elapsed=%3 state=%4 inventory=%5",_class,_extraEmpties,diag_tickTime - _started,_state,magazinesAmmoFull [_object,true]]; _last = _state; };
        sleep 0.1;
    };
    diag_log format ["[IVCS AMMO PROBE] RESULT class=%1 extra=%2 ammo=%3 requests=%4 transfers=%5 attempts=%6 empty=%7 inventory=%8",_class,_extraEmpties,_object ammo primaryWeapon _object,count (_entity get "ammoRequests"),_entity get "ammoTransfers",_r getOrDefault ["probeAttempts",0],{ (_x select 1) == 0 } count magazinesAmmoFull [_object,true],magazinesAmmoFull [_object,true]];
    [_entity] call IVCS_VirtualSpace_Group_despawn; [_entity] call IVCS_VirtualSpace_unregisterEntity;
} forEach [["B_Soldier_F",0],["B_Soldier_TL_F",0],["B_Soldier_F",40]];
IVCS_Ammo_createRequest = IVCS_Probe_OriginalCreateRequest;
diag_log "[IVCS TASK TEST] DONE passed=0 failed=0";
