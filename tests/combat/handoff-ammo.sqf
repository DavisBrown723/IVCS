// Regression for spent magazines, live capacity and usable ammunition after handoff.
waitUntil { time > 0 };
call compile preprocessFileLineNumbers "IVCS\initFunctions.sqf";
call compile preprocessFileLineNumbers "IVCS\EntityTasks\startup.sqf";
IVCS_Common_WeaponInfo = createHashMap; IVCS_Common_MagazineInfo = createHashMap;
IVCS_Common_AmmoInfo = createHashMap; IVCS_Common_UnitInfo = createHashMap;
IVCS_Common_WeaponAliases = createHashMap;
IVCS_Paths_Generator = createHashMapFromArray [["requestQueue",[]],["currentRequest",[]]];
IVCS_VirtualSpace_Controller = [false] call IVCS_VirtualSpace_createController;
removeMissionEventHandler ["EachFrame",IVCS_VirtualSpace_Controller get "onFrameHandlerID"];
private _combat = IVCS_VirtualSpace_Controller get "combat";
_combat set ["accuracyScale",0];
private _passed = 0; private _failed = 0;
private _assert = {
    params ["_ok","_label"];
    if (_ok) then { _passed = _passed + 1; } else { _failed = _failed + 1; };
    diag_log format ["[IVCS TASK TEST] %1 %2",if (_ok) then {"PASS"} else {"FAIL"},_label];
};
private _make = {
    params ["_class",["_side","WEST"],["_pos",[14500,16400,0]]];
    private _r = [_class,"u_0"] call IVCS_VirtualSpace_Group_createUnit;
    private _d = [_class,"u_1"] call IVCS_VirtualSpace_Group_createUnit;
    [_side,"BLU_F",_pos,[_r,_d]] call IVCS_VirtualSpace_Group_createEntity
};
private _clean = {
    params ["_entity"];
    if (_entity get "active") then { [_entity] call IVCS_VirtualSpace_Group_despawn; };
    [_entity] call IVCS_VirtualSpace_unregisterEntity;
};
// Consume a real one-round magazine without relying on production cleanup to form expectations.
west setFriend [east,0]; east setFriend [west,0];
private _blue = ["B_Soldier_F"] call _make;
private _red = ["O_Soldier_F","EAST",[14700,16400,0]] call _make;
private _unit = (_blue get "units") select 0;
private _spent = ["30Rnd_65x39_caseless_mag",1,[]];
private _spare = ["30Rnd_65x39_caseless_mag_Tracer",17,[]];
_unit set ["weapons",[["arifle_MX_F",[_spent,_spare]]]];
private _engagement = [_blue,_red,0,42] call IVCS_Combat_start;
[_engagement,[_blue,_red],0.5] call IVCS_Combat_step;
[(_spent select 1) == 0 && { ((_unit get "weapons") select 0 select 1) isEqualTo [_spare] },"virtual firing removes only the spent magazine"] call _assert;
[(_spare select 1) == 17 && { (_unit get "fireDelay") >= 3 },"discarding a spent magazine preserves spare rounds and reload delay"] call _assert;
// Legacy zero records still get sanitized at the actual combat handoff.
(((_unit get "weapons") select 0) select 1) pushBack ["30Rnd_65x39_caseless_mag",0,[]];
(_unit get "magazineCargo") pushBack ["30Rnd_65x39_caseless_green",0,[]];
[_blue] call IVCS_VirtualSpace_Group_spawn;
[(_engagement get "mode") == "native" && { _red get "active" },"mid-combat handoff still spawns both groups"] call _assert;
[{ (_x select 1) == 0 } count magazinesAmmoFull [_unit get "object",true] == 0,"combat handoff restores no empty weapon or cargo magazines"] call _assert;
{ [_x] call _clean; } forEach [_blue,_red];

IVCS_HandoffAmmo_OriginalCreateRequest = IVCS_Ammo_createRequest;
IVCS_Ammo_createRequest = {
    private _r = _this select 1;
    _r set ["testAttempts",(_r getOrDefault ["testAttempts",0]) + 1];
    _this call IVCS_HandoffAmmo_OriginalCreateRequest;
};
{
    _x params ["_class","_extra"];
    private _entity = [_class] call _make;
    private _r = (_entity get "units") select 0; private _d = (_entity get "units") select 1;
    private _rifle = ((_r get "weapons") select { (([_x select 0] call IVCS_Ammo_getWeaponProfile) select 0) == 1 }) select 0;
    private _magazineClass = (_rifle select 1 select 0) select 0;
    { _x set [1,0]; } forEach (_rifle select 1);
    for "_i" from 1 to _extra do { (_rifle select 1) pushBack [_magazineClass,0,[]]; };
    [_entity] call IVCS_VirtualSpace_Group_spawn;
    private _object = _r get "object";
    { private _o = _x get "object"; _o disableAI "TARGET"; _o disableAI "AUTOTARGET"; _o disableAI "MOVE"; _o allowDamage false; } forEach [_r,_d];
    _object setPosATL [14500,16400,0]; (_d get "object") setPosATL [14500.5,16400,0];
    [{ (_x select 1) == 0 } count magazinesAmmoFull [_object,true] == 0,_class + " handoff discards every depleted magazine"] call _assert;
    [_object canAdd _magazineClass,_class + " spent magazines do not occupy receiving capacity"] call _assert;
    if (_class == "B_Soldier_F" && { _extra == 0 }) then {
        private _weapon = primaryWeapon _object;
        private _deadline = diag_tickTime + 2;
        waitUntil { _object selectWeapon _weapon; sleep 0.05; currentMuzzle _object == _weapon || { diag_tickTime > _deadline } };
        private _delivered = createHashMapFromArray [["weapon",_weapon],["recipient",_r],["delivered",[_weapon,_magazineClass]]];
        [currentMuzzle _object == _weapon && { (_object ammo _weapon) == 0 } && {
            [_delivered,[_r,true] call IVCS_Ammo_snapshot] call IVCS_Ammo_reloadRequest
        },"transiently missing delivered magazine retains reload ownership"] call _assert;
    };
    private _totalBefore = 0;
    { { _totalBefore = _totalBefore + (_x select 1); } forEach magazinesAmmoFull [_x get "object",true]; } forEach [_r,_d];
    private _deadline = diag_tickTime + 20;
    while { ((_object ammo primaryWeapon _object) == 0 || { (_entity get "ammoRequests") isNotEqualTo [] }) && { diag_tickTime < _deadline } } do {
        [_entity,IVCS_SimulationTime,false] call IVCS_Ammo_updateGroup;
        sleep 0.1;
    };
    [(_object ammo primaryWeapon _object) > 0 && { (_entity get "ammoRequests") isEqualTo [] },_class + " collection completes through a real native reload"] call _assert;
    [(_entity get "ammoTransfers") == 1 && { (_r getOrDefault ["testAttempts",0]) == 1 },_class + " receives one magazine without repeated collection"] call _assert;
    private _totalAfter = 0;
    { { _totalAfter = _totalAfter + (_x select 1); } forEach magazinesAmmoFull [_x get "object",true]; } forEach [_r,_d];
    [_totalAfter == _totalBefore,_class + " handoff sharing conserves live rounds"] call _assert;
    _object setVariable ["testFired",0];
    _object addEventHandler ["Fired",{ params ["_object"]; _object setVariable ["testFired",(_object getVariable "testFired") + 1]; }];
    _object selectWeapon primaryWeapon _object;
    _deadline = diag_tickTime + 3;
    waitUntil {
        _object forceWeaponFire [currentMuzzle _object,(weaponState _object) select 2];
        sleep 0.1;
        (_object getVariable "testFired") > 0 || { diag_tickTime > _deadline }
    };
    [(_object getVariable "testFired") > 0,_class + " weapon can fire after collection"] call _assert;
    [_entity,IVCS_SimulationTime + 6,false] call IVCS_Ammo_updateGroup;
    [(_r getOrDefault ["testAttempts",0]) == 1 && { (_entity get "ammoRequests") isEqualTo [] },_class + " loaded ammunition prevents another collection cycle"] call _assert;
    diag_log format ["[IVCS HANDOFF AMMO] class=%1 legacyEmpty=%2 transfers=%3 attempts=%4 ammo=%5 fired=%6",_class,_extra,_entity get "ammoTransfers",_r getOrDefault ["testAttempts",0],_object ammo primaryWeapon _object,_object getVariable "testFired"];
    [_entity] call _clean;
} forEach [["B_Soldier_F",0],["B_Soldier_TL_F",0],["B_soldier_AR_F",0],["O_Soldier_TL_F",0],["O_Soldier_AR_F",0],["B_Soldier_F",40]];

// Even genuinely full inventory must not produce repeated approach/collection orders.
private _entity = ["B_Soldier_F"] call _make;
private _r = (_entity get "units") select 0; private _d = (_entity get "units") select 1;
_r set ["weapons",[["arifle_MX_F",[]]]]; _r set ["magazineCargo",[]];
[_entity] call IVCS_VirtualSpace_Group_spawn;
private _object = _r get "object";
(uniformContainer _object) addItemCargoGlobal ["ToolKit",100];
(vestContainer _object) addItemCargoGlobal ["ToolKit",100];
[!(_object canAdd "30Rnd_65x39_caseless_mag"),"full inventory fixture cannot receive ammunition"] call _assert;
for "_i" from 0 to 20 do { [_entity,IVCS_SimulationTime + _i,false] call IVCS_Ammo_updateGroup; };
[(_r getOrDefault ["testAttempts",0]) == 0 && { (_entity get "ammoRequests") isEqualTo [] },"full recipient never repeatedly visits a donor"] call _assert;
[(_entity get "ammoTransfers") == 0 && { !isForcedWalk _object },"full recipient retains donor ammunition and movement state"] call _assert;
// Free space and let the existing retry policy discover a donor again.
clearItemCargoGlobal uniformContainer _object; clearItemCargoGlobal vestContainer _object;
[_entity,IVCS_SimulationTime + 30,false] call IVCS_Ammo_updateGroup;
[count (_entity get "ammoRequests") == 1,"freeing receiving capacity allows a subsequent request"] call _assert;
// Capacity changes after reservation must cancel before playing the collection action.
(uniformContainer _object) addItemCargoGlobal ["ToolKit",100];
(vestContainer _object) addItemCargoGlobal ["ToolKit",100];
_object setPosATL [14500,16400,0]; (_d get "object") setPosATL [14500.5,16400,0];
[_entity,IVCS_SimulationTime + 31,false] call IVCS_Ammo_updateGroup;
[(_entity get "ammoRequests") isEqualTo [] && { (_entity get "ammoTransfers") == 0 },"capacity lost after reservation cancels before collection"] call _assert;
[_entity] call _clean;
IVCS_Ammo_createRequest = IVCS_HandoffAmmo_OriginalCreateRequest;
[count (((IVCS_VirtualSpace_Controller get "entities") get "ALL")) == 0,"handoff regression cleans up its entities"] call _assert;
diag_log format ["[IVCS TASK TEST] DONE passed=%1 failed=%2",_passed,_failed];
