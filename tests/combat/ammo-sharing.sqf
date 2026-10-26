// Run: powershell -File tests/tasks/run.ps1 -TestScript tests/combat/ammo-sharing.sqf -Port 2496 -TimeoutSeconds 180
waitUntil { time > 0 };
call compile preprocessFileLineNumbers "IVCS\initFunctions.sqf";
call compile preprocessFileLineNumbers "IVCS\EntityTasks\startup.sqf";
IVCS_Common_WeaponInfo = createHashMap;
IVCS_Common_MagazineInfo = createHashMap;
IVCS_Common_AmmoInfo = createHashMap;
IVCS_Common_UnitInfo = createHashMap;
IVCS_Common_WeaponAliases = createHashMap;
IVCS_Paths_Generator = createHashMapFromArray [["requestQueue", []], ["currentRequest", []]];
IVCS_VirtualSpace_Controller = [false] call IVCS_VirtualSpace_createController;
removeMissionEventHandler ["EachFrame", IVCS_VirtualSpace_Controller get "onFrameHandlerID"];
IVCS_Sharing_Passed = 0; IVCS_Sharing_Failed = 0;
private _assert = {
    params ["_ok", "_label"];
    if (_ok) then { IVCS_Sharing_Passed = IVCS_Sharing_Passed + 1; } else { IVCS_Sharing_Failed = IVCS_Sharing_Failed + 1; };
    diag_log format ["[IVCS TASK TEST] %1 %2", if (_ok) then { "PASS" } else { "FAIL" }, _label];
};
private _settings = (IVCS_VirtualSpace_Controller get "combat") get "ammoSharing";
[(_settings get "collectionDistance") == 1, "native collection distance is exactly one metre"] call _assert;
["100Rnd_65x39_caseless_mag" in ((["arifle_MX_F"] call IVCS_Common_getWeaponInfo) select 2),"compatibility includes engine magazine wells"] call _assert;
private _mag = { params ["_rounds", ["_class", "30Rnd_65x39_caseless_mag"]]; [_class,_rounds,["infantry"]] };
private _make = {
    params [["_count", 2]];
    private _units = [];
    for "_i" from 0 to (_count-1) do {
        private _unit = ["B_Soldier_F",format ["u_%1",_i]] call IVCS_VirtualSpace_Group_createUnit;
        _unit set ["weapons",[["arifle_MX_F",[]],["hgun_P07_F",[["16Rnd_9x21_Mag",16,["infantry"]]]]]];
        _unit set ["magazineCargo",[]];
        _units pushBack _unit;
    };
    ["WEST","BLU_F",[14500,16400,0],_units] call IVCS_VirtualSpace_Group_createEntity
};
private _cleanup = {
    params ["_entity"];
    if (_entity get "active") then { [_entity] call IVCS_VirtualSpace_Group_despawn; };
    [_entity] call IVCS_VirtualSpace_unregisterEntity;
};
private _total = {
    params ["_entity"];
    private _total = 0;
    {
        { _total = _total + (_x select 1); } forEach (([_x,_entity get "active"] call IVCS_Ammo_snapshot) select 3);
    } forEach (_entity get "units");
    _total
};
private _e = [] call _make;
private _r = (_e get "units") select 0; private _d = (_e get "units") select 1;
((_d get "weapons") select 0) set [1,[[30] call _mag,[30] call _mag,[17] call _mag]];
private _before = [_e] call _total;
[_e,0,false] call IVCS_Ammo_updateGroup;
[count (_e get "ammoRequests") == 1,"primary exhaustion requests ammunition while pistol ammo remains"] call _assert;
[_e,2,false] call IVCS_Ammo_updateGroup;
[(_e get "ammoTransfers") == 0,"virtual approach delay prevents instant sharing"] call _assert;
[_e,3,false] call IVCS_Ammo_updateGroup;
[((_e get "ammoRequests") select 0) get "phase" == "collecting","virtual approach advances to collection"] call _assert;
[_e,5,false] call IVCS_Ammo_updateGroup;
[(_e get "ammoTransfers") == 1,"virtual collection transfers one magazine"] call _assert;
[((_r get "weapons") select 0 select 1 select 0 select 1) == 17,"virtual transfer preserves partial magazine rounds"] call _assert;
[count ((_d get "weapons") select 0 select 1) == 2,"donor retains loaded magazine and one spare"] call _assert;
[([_e] call _total) == _before,"virtual sharing conserves total rounds"] call _assert;
[(_r get "fireDelay") >= 3,"received virtual ammunition requires normal reload time"] call _assert;
[_e] call _cleanup;

_e = [3] call _make; _r = (_e get "units") select 0; _d = (_e get "units") select 2;
_d set ["weapons",[]];
_d set ["magazineCargo",[[17] call _mag,[12, "30Rnd_65x39_caseless_green"] call _mag]];
[_e,0,false] call IVCS_Ammo_updateGroup;
[count (_e get "ammoRequests") == 1,"one surplus magazine cannot be reserved by two recipients"] call _assert;
[_e,3,false] call IVCS_Ammo_updateGroup; [_e,5,false] call IVCS_Ammo_updateGroup;
[(_e get "ammoTransfers") == 1 && { count (_d get "magazineCargo") == 1 },"non-bearer donors share ammunition they cannot use"] call _assert;
[((_d get "magazineCargo") select 0 select 0) == "30Rnd_65x39_caseless_green","incompatible magazines remain with donor"] call _assert;
[_e] call _cleanup;

_e = [] call _make; _d = (_e get "units") select 1;
((_d get "weapons") select 0) set [1,[[30] call _mag,[30] call _mag]];
[_e,0,false] call IVCS_Ammo_updateGroup;
[count (_e get "ammoRequests") == 0,"loaded magazine plus last spare cannot be donated"] call _assert;
_d set ["magazineCargo",[[15] call _mag]];
[_e,1,false] call IVCS_Ammo_updateGroup;
[count (_e get "ammoRequests") == 0,"failed requests use a retry cooldown"] call _assert;
[_e,5,false] call IVCS_Ammo_updateGroup;
[count (_e get "ammoRequests") == 1,"retry discovers newly available ammunition"] call _assert;
((_d get "magazineCargo") select 0) set [1,0];
[_e,6,false] call IVCS_Ammo_updateGroup;
[count (_e get "ammoRequests") == 0 && { (_e get "ammoTransfers") == 0 },"consumed reservation cancels without creating ammo"] call _assert;
[_e] call _cleanup;

_e = [] call _make; _d = (_e get "units") select 1;
_d set ["magazineCargo",[[15] call _mag]];
[_e,0,false] call IVCS_Ammo_updateGroup;
_d set ["damage",1];
[_e,1,false] call IVCS_Ammo_updateGroup;
[count (_e get "ammoRequests") == 0,"dead donor cancels pending request"] call _assert;
[_e] call _cleanup;

// Handguns use the same request and reserve policy as rifles.
_e = [] call _make; _r = (_e get "units") select 0; _d = (_e get "units") select 1;
((_r get "weapons") select 1) set [1,[]];
((_d get "weapons") select 1) set [1,[[16,"16Rnd_9x21_Mag"] call _mag,[16,"16Rnd_9x21_Mag"] call _mag,[8,"16Rnd_9x21_Mag"] call _mag]];
[_e,0,false] call IVCS_Ammo_updateGroup;
[((_e get "ammoRequests") select 0) get "weapon" == "hgun_P07_F","empty handgun requests ammunition when no rifle donor exists"] call _assert;
[_e,3,false] call IVCS_Ammo_updateGroup; [_e,5,false] call IVCS_Ammo_updateGroup;
[((_r get "weapons") select 1 select 1 select 0 select 1) == 8 && { count ((_d get "weapons") select 1 select 1) == 2 },"handgun sharing preserves partial rounds and donor reserve"] call _assert;
[_e] call _cleanup;

// Sharing must use simulation timestamps and preserve the full reload delay.
private _damageFunction = IVCS_Combat_damageUnit;
IVCS_Combat_damageUnit = {};
private _simulateSharing = {
    params ["_coarse"];
    private _blue = [] call _make;
    private _red = [] call _make;
    _red set ["side","EAST"];
    [_red,[14700,16400,0]] call IVCS_VirtualSpace_setEntityPosition;
    private _recipient = (_blue get "units") select 0;
    private _donor = (_blue get "units") select 1;
    ((_donor get "weapons") select 0) set [1,[[30] call _mag,[30] call _mag,[17] call _mag]];
    { ((_x get "weapons") select 0) set [1,[[30] call _mag,[30] call _mag,[30] call _mag]]; } forEach (_red get "units");
    private _engagement = [_blue,_red,0,321] call IVCS_Combat_start;
    private _savedSteps = (IVCS_VirtualSpace_Controller get "combat") get "stepsPerUpdate";
    (IVCS_VirtualSpace_Controller get "combat") set ["stepsPerUpdate",100];
    if (_coarse) then { [_engagement,10] call IVCS_Combat_update; } else {
        for "_time" from 0.5 to 10 step 0.5 do {
            [_engagement,_time] call IVCS_Combat_update;
            if (_time == 8) then {
                [((_recipient get "weapons") select 0 select 1 select 0 select 1) == 17,"virtual recipient waits the full reload delay after delivery"] call _assert;
            };
            if (_time == 9) then {
                [((_recipient get "weapons") select 0 select 1 select 0 select 1) == 16,"virtual recipient resumes primary fire after its reload"] call _assert;
            };
        };
    };
    private _result = [_blue get "ammoTransfers",[_blue] call _total,[_red] call _total,_engagement get "shots",_recipient get "fireDelay"];
    (IVCS_VirtualSpace_Controller get "combat") set ["stepsPerUpdate",_savedSteps];
    [_blue] call _cleanup; [_red] call _cleanup;
    _result
};
private _fine = [false] call _simulateSharing;
private _coarse = [true] call _simulateSharing;
[_fine isEqualTo _coarse,"coarse and fine combat updates produce identical sharing and ammunition use"] call _assert;
[(_fine select 0) == 1,"production virtual combat scheduler completes an ammunition request"] call _assert;
IVCS_Combat_damageUnit = _damageFunction;

// Native adapter: exact backpack magazine, loaded weapons untouched, strict range.
private _makeNative = {
    private _entity = [] call _make;
    private _donor = (_entity get "units") select 1;
    ((_donor get "weapons") select 0) set [1,[[30] call _mag,[30] call _mag]];
    [_entity] call IVCS_VirtualSpace_Group_spawn;
    { (_x get "object") disableAI "ALL"; } forEach (_entity get "units");
    private _object = _donor get "object";
    _object addBackpack "B_AssaultPack_blk";
    (backpackContainer _object) addMagazineAmmoCargo ["30Rnd_65x39_caseless_mag",1,17];
    ((_entity get "units") select 0 get "object") setPosATL [14500,16400,0];
    _object setPosATL [14502,16400,0];
    _entity
};
_e = call _makeNative; _r = (_e get "units") select 0; _d = (_e get "units") select 1;
_before = [_e] call _total;
private _loadedBefore = ((_d get "object") ammo primaryWeapon (_d get "object"));
[_e,0,false] call IVCS_Ammo_updateGroup;
[count (_e get "ammoRequests") == 1,"native unit requests compatible surplus backpack magazine"] call _assert;
(_r get "object") setPosATL [14500.8,16400,0];
[_e,1,false] call IVCS_Ammo_updateGroup;
[((_e get "ammoRequests") select 0) get "phase" == "approaching","distance greater than one metre cannot start collection"] call _assert;
(_r get "object") setPosATL [14501.2,16400,0];
[_e,2,false] call IVCS_Ammo_updateGroup;
[((_e get "ammoRequests") select 0) get "phase" == "collecting","arrival inside one metre starts collection"] call _assert;
[_e,4,false] call IVCS_Ammo_updateGroup;
[(_e get "ammoTransfers") == 1,"native collection transfers a physical magazine"] call _assert;
[([_e] call _total) == _before,"native sharing conserves total rounds"] call _assert;
[((_d get "object") ammo primaryWeapon (_d get "object")) == _loadedBefore,"native sharing leaves donor loaded weapon untouched"] call _assert;
[(magazinesAmmoCargo backpackContainer (_d get "object")) findIf { (_x select 1) == 17 } == -1,"transferred partial magazine is removed from actual donor backpack"] call _assert;
[(magazinesAmmoFull [(_r get "object"),true]) findIf { (_x select 0) == "30Rnd_65x39_caseless_mag" && { (_x select 1) == 17 } } != -1,"recipient receives exact remaining rounds"] call _assert;
[!isForcedWalk (_r get "object"),"native completion restores original walking setting"] call _assert;
private _after = [_e] call _total;
[_e] call IVCS_VirtualSpace_Group_despawn; [_e] call IVCS_VirtualSpace_Group_spawn;
[([_e] call _total) == _after,"shared native magazines survive despawn and respawn"] call _assert;
[_e] call _cleanup;

_e = call _makeNative; _r = (_e get "units") select 0;
[_e,0,false] call IVCS_Ammo_updateGroup;
[_e] call IVCS_VirtualSpace_Group_despawn;
[count (_e get "ammoRequests") == 0,"despawn cancels movement requests and native inventory tokens"] call _assert;
[_e] call IVCS_VirtualSpace_Group_spawn;
[(_e get "ammoTransfers") == 0,"transition does not complete an obsolete request"] call _assert;
[_e] call _cleanup;

_e = call _makeNative; _r = (_e get "units") select 0;
_before = [_e] call _total;
(uniformContainer (_r get "object")) addItemCargoGlobal ["ToolKit",100];
(vestContainer (_r get "object")) addItemCargoGlobal ["ToolKit",100];
[!((_r get "object") canAdd "30Rnd_65x39_caseless_mag"),"capacity fixture cannot accept another magazine"] call _assert;
[_e,0,false] call IVCS_Ammo_updateGroup;
[count (_e get "ammoRequests") == 0 && { !isForcedWalk (_r get "object") },"full recipient never starts a futile collection trip"] call _assert;
(_r get "object") setPosATL [14501.2,16400,0];
[_e,1,false] call IVCS_Ammo_updateGroup; [_e,3,false] call IVCS_Ammo_updateGroup;
[(_e get "ammoTransfers") == 0 && { ([_e] call _total) == _before },"failed native insertion leaves both inventories unchanged"] call _assert;
[_e] call _cleanup;

_e = call _makeNative; _before = [_e] call _total;
[_e,0,false] call IVCS_Ammo_updateGroup; [_e,31,false] call IVCS_Ammo_updateGroup;
[count (_e get "ammoRequests") == 0 && { ([_e] call _total) == _before },"unreachable donor times out without a transfer"] call _assert;
[_e] call _cleanup;

// Actual AI pathfinding, without teleporting the recipient to the donor.
_e = call _makeNative; _r = (_e get "units") select 0; _d = (_e get "units") select 1;
private _object = _r get "object";
_object enableAI "ALL";
_object disableAI "TARGET"; _object disableAI "AUTOTARGET";
(_e get "group") setBehaviourStrong "COMBAT";
doStop _object;
(_e get "group") setCombatMode "BLUE";
_object setPosATL [14500,16400,0]; (_d get "object") setPosATL [14508,16400,0];
private _started = diag_tickTime;
private _deadline = _started + 40;
private _lastPhase = "";
while { ((_e get "ammoTransfers") == 0 || { (_e get "ammoRequests") isNotEqualTo [] }) && { diag_tickTime < _deadline } } do {
    if ((_e get "ammoRequests") isEqualTo []) then { [_e,0.1] call IVCS_VirtualSpace_Group_update; };
    [] call IVCS_Ammo_onFrame;
    [] call IVCS_Ammo_searchOnFrame;
    private _phase = if ((_e get "ammoRequests") isEqualTo []) then { "released" } else { ((_e get "ammoRequests") select 0) get "phase" };
    if (_phase != _lastPhase) then {
        diag_log format ["[IVCS TASK TEST] SHARING_RELOAD phase=%1 elapsed=%2 weapon=%3 state=%4",_phase,diag_tickTime - _started,currentWeapon _object,weaponState _object];
        _lastPhase = _phase;
    };
    sleep 0.1;
};
diag_log format ["[IVCS TASK TEST] SHARING_PATH distance=%1 duration=%2 requests=%3",_object distance (_d get "object"),diag_tickTime - _started,(_e get "ammoRequests") apply { _x get "phase" }];
[count ((_settings get "nativeQueue") arrayIntersect [_e get "id"]) <= 1,"pending native scheduling never duplicates group IDs"] call _assert;
[(_e get "ammoTransfers") == 1,"native group update sends recipient to donor and collects within one metre in combat behavior"] call _assert;
[!isForcedWalk _object,"walking approach restores its previous speed setting"] call _assert;
sleep 3;
diag_log format ["[IVCS TASK TEST] SHARING_FINAL primary=%1 ammo=%2 state=%3 inventory=%4",primaryWeapon _object,_object ammo primaryWeapon _object,weaponState _object,magazinesAmmoFull [_object,true]];
[(_object ammo primaryWeapon _object) == 17,"live recipient reloads the collected magazine into its rifle"] call _assert;
[_e] call _cleanup;
[(_settings get "nativeQueue") isEqualTo [],"sharing teardown clears the pending native queue"] call _assert;
[count (((IVCS_VirtualSpace_Controller get "entities") get "ALL")) == 0,"sharing test teardown removes all entities"] call _assert;
diag_log format ["[IVCS TASK TEST] DONE passed=%1 failed=%2",IVCS_Sharing_Passed,IVCS_Sharing_Failed];
