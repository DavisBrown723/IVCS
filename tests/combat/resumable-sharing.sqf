// Exercise real frame search cursors, changing inventories, and lifecycle cleanup.
waitUntil { time > 0 };
call compile preprocessFileLineNumbers "IVCS\initFunctions.sqf";
call compile preprocessFileLineNumbers "IVCS\EntityTasks\startup.sqf";
IVCS_Common_WeaponInfo = createHashMap; IVCS_Common_MagazineInfo = createHashMap;
IVCS_Common_AmmoInfo = createHashMap; IVCS_Common_UnitInfo = createHashMap;
IVCS_Common_WeaponAliases = createHashMap;
IVCS_Paths_Generator = createHashMapFromArray [["requestQueue",[]],["currentRequest",[]]];
IVCS_VirtualSpace_Controller = [false] call IVCS_VirtualSpace_createController;
removeMissionEventHandler ["EachFrame",IVCS_VirtualSpace_Controller get "onFrameHandlerID"];
private _passed = 0; private _failed = 0;
private _assert = {
    params ["_ok","_label"];
    if (_ok) then { _passed = _passed + 1; } else { _failed = _failed + 1; };
    diag_log format ["[IVCS TASK TEST] %1 %2",if (_ok) then {"PASS"} else {"FAIL"},_label];
};
private _combat = IVCS_VirtualSpace_Controller get "combat";
private _settings = _combat get "ammoSharing";
private _mag = { params ["_rounds"]; ["30Rnd_65x39_caseless_mag",_rounds,["infantry"]] };
private _make = {
    private _units = [];
    for "_i" from 0 to 7 do {
        private _unit = ["B_Soldier_F",format ["u_%1",_i]] call IVCS_VirtualSpace_Group_createUnit;
        _unit set ["weapons",[["arifle_MX_F",[[30] call _mag,[30] call _mag]],["hgun_P07_F",[["16Rnd_9x21_Mag",16,["infantry"]]]]]];
        _unit set ["magazineCargo",[]]; _units pushBack _unit;
    };
    ((_units select 0) get "weapons" select 0) set [1,[]];
    (_units select 7) set ["magazineCargo",[[17] call _mag]];
    ["WEST","BLU_F",[14500,16400,0],_units] call IVCS_VirtualSpace_Group_createEntity
};
private _drain = {
    params ["_entity",["_now",0.1]];
    for "_i" from 1 to 64 do {
        if ((_entity get "ammoSearch") isEqualTo []) exitWith {};
        [_entity,_now,2] call IVCS_Ammo_advanceSearch;
    };
};
private _e = call _make;
IVCS_Search_OriginalSnapshot = IVCS_Ammo_snapshot; IVCS_Search_Snapshots = 0;
IVCS_Ammo_snapshot = { IVCS_Search_Snapshots = IVCS_Search_Snapshots + 1; _this call IVCS_Search_OriginalSnapshot; };
[_e,0] call IVCS_Ammo_updateGroup;
[IVCS_Search_Snapshots == 0 && { (_e get "ammoSearch" get "scanIndex") == 4 },"new discovery checks four unit inventories before donor work"] call _assert;
[(_e get "ammoRequests") isEqualTo [] && { (_e get "ammoSearch") isNotEqualTo [] },"large-group discovery remains pending after bounded work"] call _assert;
[(_e get "id") in (_settings get "searchQueue"),"virtual searches enter the shared frame queue"] call _assert;
private _cursor = (_e get "ammoSearch") get "scanIndex";
[diag_tickTime - 1] call IVCS_Ammo_searchOnFrame;
[(_e get "ammoSearch" get "scanIndex") == _cursor,"expired shared deadline performs no needs or donor work"] call _assert;
IVCS_SimulationTime = 0.1; [] call IVCS_Ammo_searchOnFrame;
[(_e get "ammoSearch" get "donorIndex") == 3 && { IVCS_Search_Snapshots == 2 },"a later frame finishes needs and inspects at most two donors"] call _assert;
[_e] call _drain;
[count (_e get "ammoRequests") == 1 && { (_e get "ammoSearch") isEqualTo [] },"later slices finish a compatible reservation"] call _assert;
private _request = (_e get "ammoRequests") select 0;
[(_request get "donor") isEqualRef ((_e get "units") select 7),"stable donor order finds the surplus in the last unit"] call _assert;
IVCS_Search_Snapshots = 0;
[_e,1] call IVCS_Ammo_updateGroup;
[IVCS_Search_Snapshots == 0 && { (_request get "phase") == "approaching" },"virtual approach waiting checks need and token without donor snapshots"] call _assert;
[_e,3.1] call IVCS_Ammo_updateGroup; [_e,5.1] call IVCS_Ammo_updateGroup;
[(_e get "ammoTransfers") == 1 && { ((_e get "units" select 0) get "weapons" select 0 select 1 select 0 select 1) == 17 },"deferred search preserves partial rounds and normal approach/collection delays"] call _assert;
IVCS_Ammo_snapshot = IVCS_Search_OriginalSnapshot;
[_e] call IVCS_VirtualSpace_unregisterEntity;

// A previously best token becomes the donor's last reserve before commit.
_e = call _make;
private _donor = (_e get "units") select 1;
_donor set ["magazineCargo",[[17] call _mag]];
((_e get "units") select 7) set ["magazineCargo",[]];
[_e,0] call IVCS_Ammo_updateGroup;
((_donor get "weapons") select 0 select 1) deleteAt 1;
[_e] call _drain;
[(_e get "ammoRequests") isEqualTo [] && { (_donor get "magazineCargo" select 0 select 1) == 17 },"commit rejects a token that became the donor's final spare"] call _assert;
[_e] call IVCS_VirtualSpace_unregisterEntity;

// A pending promise must never take the donor's last spare at collection.
_e = call _make; [_e,0] call IVCS_Ammo_updateGroup; [_e] call _drain;
_donor = (_e get "units") select 7;
((_donor get "weapons") select 0 select 1) deleteAt 1;
[_e,3.1] call IVCS_Ammo_updateGroup; [_e,5.1] call IVCS_Ammo_updateGroup;
[(_e get "ammoTransfers") == 0 && { (_donor get "magazineCargo" select 0 select 1) == 17 },"collection revalidates reserves after a waiting period"] call _assert;
[_e] call IVCS_VirtualSpace_unregisterEntity;

// Replacing a stale winner must still discover another eligible donor.
_e = call _make;
_donor = (_e get "units") select 1;
_donor set ["magazineCargo",[[17] call _mag]];
[_e,0] call IVCS_Ammo_updateGroup;
((_donor get "weapons") select 0 select 1) deleteAt 1;
[_e] call _drain;
[count (_e get "ammoRequests") == 1 && { ((_e get "ammoRequests") select 0 get "donor") isEqualRef ((_e get "units") select 7) },"stale winning token reschedules discovery and finds another donor"] call _assert;
[_e] call IVCS_VirtualSpace_unregisterEntity;

_e = call _make; [_e,0] call IVCS_Ammo_updateGroup;
((_e get "units") select 0) set ["magazineCargo",[[11] call _mag]];
[_e] call _drain;
[(_e get "ammoRequests") isEqualTo [],"recipient pickup while searching cancels redundant reservation"] call _assert;
[_e] call IVCS_VirtualSpace_unregisterEntity;

_e = call _make; [_e,0] call IVCS_Ammo_updateGroup;
private _recipient = (_e get "units") select 0;
[_e,_recipient] call IVCS_VirtualSpace_Group_RemoveUnit;
[_e] call _drain;
[(_e get "ammoRequests") isEqualTo [] && { (_e get "ammoSearch") isEqualTo [] },"removed recipient cannot receive a deferred request"] call _assert;
[_e] call IVCS_VirtualSpace_unregisterEntity;

_e = call _make; [_e,0] call IVCS_Ammo_updateGroup;
[_e] call IVCS_VirtualSpace_Group_spawn;
[(_e get "ammoSearch") isEqualTo [] && { !((_e get "id") in (_settings get "searchQueue")) },"spawn cancels virtual search snapshots and cursors"] call _assert;
{ _x disableAI "ALL"; } forEach units (_e get "group");
// Empty the actual native rifle after restore, leaving another unit's surplus.
private _object = ((_e get "units") select 0) get "object";
{ _object removeMagazines _x; } forEach (([primaryWeapon _object] call IVCS_Common_getWeaponInfo) select 2);
[_e,0] call IVCS_Ammo_updateGroup;
[(_e get "ammoSearch") isNotEqualTo [],"native discovery uses the same resumable worker"] call _assert;
[_e] call IVCS_VirtualSpace_Group_despawn;
[(_e get "ammoSearch") isEqualTo [] && { !((_e get "id") in (_settings get "searchQueue")) },"despawn cancels native search and inventory tokens"] call _assert;
[_e] call IVCS_VirtualSpace_unregisterEntity;

// Two recipients must never claim the same single surplus magazine.
_e = call _make;
((_e get "units") select 1 get "weapons" select 0) set [1,[]];
[_e,0] call IVCS_Ammo_updateGroup; [_e] call _drain;
[count (_e get "ammoRequests") == 1,"multiple deferred recipients cannot reserve the same token"] call _assert;
[_e] call IVCS_VirtualSpace_unregisterEntity;

// Force a slow slice to prove the frame queue rotates without starving peers.
private _a = call _make; private _b = call _make;
[_a,0] call IVCS_Ammo_updateGroup; [_b,0] call IVCS_Ammo_updateGroup;
IVCS_Search_OriginalAdvance = IVCS_Ammo_advanceSearch; IVCS_Search_Visited = [];
IVCS_Ammo_advanceSearch = {
    IVCS_Search_Visited pushBack ((_this select 0) get "id");
    _this call IVCS_Search_OriginalAdvance;
    private _until = diag_tickTime + 0.004; waitUntil { diag_tickTime >= _until };
};
_settings set ["searchBudgetMs",1]; [] call IVCS_Ammo_searchOnFrame;
[IVCS_Search_Visited isEqualTo [_a get "id"] && { (_settings get "searchQueue") isEqualTo [_b get "id",_a get "id"] },"search budget yields after a slow slice and rotates fairly"] call _assert;
IVCS_Ammo_advanceSearch = IVCS_Search_OriginalAdvance;
[] call IVCS_Ammo_searchOnFrame;
[((_b get "ammoSearch") get "donorIndex") == 3 && { (_b get "ammoSearch" get "scanIndex") == -1 },"next frame finishes needs and advances the previously deferred peer"] call _assert;
[_a] call IVCS_VirtualSpace_unregisterEntity; [_b] call IVCS_VirtualSpace_unregisterEntity;
[(_settings get "searchQueue") isEqualTo [] && { (_settings get "nativeQueue") isEqualTo [] },"unregister cleans all frame work queues"] call _assert;

diag_log format ["[IVCS TASK TEST] DONE passed=%1 failed=%2",_passed,_failed];
