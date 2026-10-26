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
// Differential policy checks cover ordering ties, overlapping compatibility pools,
// rifle/pistol/launcher reserves, loaded/empty magazines and incompatible cargo.
private _classes = ["30Rnd_65x39_caseless_mag","100Rnd_65x39_caseless_mag","16Rnd_9x21_Mag","NLAW_F","30Rnd_65x39_caseless_green"];
private _weaponSets = [[],["arifle_MX_F"],["arifle_MX_SW_F","arifle_MX_F"],["arifle_MX_F","hgun_P07_F","launch_NLAW_F"]];
private _comparisons = 0;
for "_case" from 0 to 47 do {
    private _magazines = [];
    for "_i" from 0 to 11 do {
        _magazines pushBack [_classes select ((_i + _case) mod 5),[0,8,17,30] select ((_i * 3 + floor (_case / 5)) mod 4),(_i + _case) mod 7 == 0,_i,objNull];
    };
    private _snapshot = [createHashMap,"",_weaponSets select (_case mod 4),_magazines];
    private _surplus = [_snapshot] call IVCS_Ammo_surplus;
    private _matches = true;
    {
        private _actual = [_snapshot,_x select 3] call IVCS_Ammo_getReservedMagazine;
        private _token = _x select 3;
        private _expectedIndex = _surplus findIf { (_x select 3) == _token };
        private _expected = if (_expectedIndex == -1) then { [] } else { _surplus select _expectedIndex };
        if (_actual isNotEqualTo _expected) then { _matches = false; };
        _comparisons = _comparisons + 1;
    } forEach _magazines;
    [_matches,format ["targeted validation matches full surplus policy for inventory %1",_case]] call _assert;
};
[_comparisons == 576,"differential policy covers 576 reserved candidates"] call _assert;
private _mag = { params ["_rounds"]; ["30Rnd_65x39_caseless_mag",_rounds,["infantry"]] };
private _make = {
    private _units = [];
    for "_i" from 0 to 2 do {
        private _u = ["B_Soldier_F",format ["arrival_%1",_i]] call IVCS_VirtualSpace_Group_createUnit;
        _u set ["weapons",[["arifle_MX_F",[]]]]; _u set ["magazineCargo",[]]; _units pushBack _u;
    };
    private _d = _units select 2;
    _d set ["weapons",[["arifle_MX_F",[[30] call _mag,[30] call _mag]]]];
    _d set ["magazineCargo",[[17] call _mag,[17] call _mag]];
    ["WEST","BLU_F",[14500,16400,0],_units] call IVCS_VirtualSpace_Group_createEntity
};
private _reserve = {
    params ["_e","_recipient","_cargoIndex",["_now",0]];
    private _units = _e get "units"; private _d = _units select 2;
    private _cargo = _d get "magazineCargo"; private _record = _cargo select _cargoIndex;
    [_e,_units select _recipient,_d,"arifle_MX_F",[_record select 0,_record select 1,false,[_cargo,_record],objNull],_now,false] call IVCS_Ammo_createRequest;
};
// Supplying a recipient before arrival skips all donor reconstruction.
private _e = call _make; [_e,0,0] call _reserve;
((_e get "units") select 0) set ["magazineCargo",[[11] call _mag]];
IVCS_Arrival_OriginalSnapshot = IVCS_Ammo_snapshot; IVCS_Arrival_Snapshots = 0;
IVCS_Ammo_snapshot = { IVCS_Arrival_Snapshots = IVCS_Arrival_Snapshots + 1; _this call IVCS_Arrival_OriginalSnapshot; };
[_e,_e get "units",3,false] call IVCS_Ammo_updateRequests;
[(_e get "ammoRequests") isEqualTo [] && { IVCS_Arrival_Snapshots == 0 } && { (_e get "ammoTransfers") == 0 },"recipient supplied before arrival cancels without snapshotting donor"] call _assert;
IVCS_Ammo_snapshot = IVCS_Arrival_OriginalSnapshot;
[_e] call IVCS_VirtualSpace_unregisterEntity;
// A record moved out of its reserved source cannot be removed from that old array.
_e = call _make; [_e,0,0] call _reserve;
private _d = (_e get "units") select 2; private _oldSource = _d get "magazineCargo";
private _record = _oldSource deleteAt 0; (_d get "weapons" select 0 select 1) pushBack _record;
[_e,_e get "units",3,false] call IVCS_Ammo_updateRequests;
[(_e get "ammoRequests") isEqualTo [] && { (_e get "ammoTransfers") == 0 } && { (_d get "weapons" select 0 select 1) findIf { _x isEqualRef _record } != -1 },"arrival rejects a token moved to a different donor source"] call _assert;
[_e] call IVCS_VirtualSpace_unregisterEntity;
// The earlier equally full spare wins ties, even with two ready requests.
_e = call _make; [_e,0,0] call _reserve; [_e,1,1] call _reserve;
_d = (_e get "units") select 2; (_d get "weapons" select 0 select 1) deleteAt 1;
[_e,_e get "units",3,false] call IVCS_Ammo_updateRequests;
[count (_e get "ammoRequests") == 1 && { ((_e get "ammoRequests") select 0 get "recipient") isEqualRef ((_e get "units") select 1) },"arrival protects first equally full spare and permits the later one"] call _assert;
[_e,_e get "units",5,false] call IVCS_Ammo_updateRequests;
[(_e get "ammoTransfers") == 1 && { count (_d get "magazineCargo") == 1 },"collection retains one reserve after tied-surplus transfer"] call _assert;
[_e] call IVCS_VirtualSpace_unregisterEntity;
// Two valid arrivals can become competing reservations at collection.
_e = call _make; [_e,0,0] call _reserve; [_e,1,1] call _reserve;
[_e,_e get "units",3,false] call IVCS_Ammo_updateRequests;
_d = (_e get "units") select 2; (_d get "weapons" select 0 select 1) deleteAt 1;
private _swapped = (_d get "magazineCargo") deleteAt 0; (_d get "magazineCargo") pushBack _swapped;
IVCS_Arrival_Snapshots = 0;
IVCS_Ammo_snapshot = { IVCS_Arrival_Snapshots = IVCS_Arrival_Snapshots + 1; _this call IVCS_Arrival_OriginalSnapshot; };
[_e,_e get "units",5,false] call IVCS_Ammo_updateRequests;
[(_e get "ammoTransfers") == 1 && { count (_d get "magazineCargo") == 1 } && { IVCS_Arrival_Snapshots == 2 },"successful transfer invalidates donor snapshot before servicing the next request"] call _assert;
IVCS_Ammo_snapshot = IVCS_Arrival_OriginalSnapshot;
[_e] call IVCS_VirtualSpace_unregisterEntity;
// Consuming the loaded magazine can promote a reserved weapon record to loaded.
_e = call _make;
_d = (_e get "units") select 2;
private _records = [[30] call _mag,[17] call _mag,[8] call _mag];
_d set ["weapons",[["arifle_MX_F",_records]]]; _d set ["magazineCargo",[]];
private _u = (_e get "units") select 0;
[_e,_u,_d,"arifle_MX_F",["30Rnd_65x39_caseless_mag",8,false,[_records,_records select 2],objNull],0,false] call IVCS_Ammo_createRequest;
[_e,_e get "units",3,false] call IVCS_Ammo_updateRequests;
(_records select 0) set [1,0]; (_records select 1) set [1,0];
[_e,_e get "units",5,false] call IVCS_Ammo_updateRequests;
[(_e get "ammoTransfers") == 0 && { (_records select 2 select 1) == 8 },"collection rejects a reserved record promoted to loaded"] call _assert;
[_e] call IVCS_VirtualSpace_unregisterEntity;

// Virtual queued commits must retain their exact five-second approach/collection timeline.
_e = call _make; [_e,0,0,0.25] call _reserve;
[_e,_e get "units",3.5,false] call IVCS_Ammo_updateRequests;
[abs (((_e get "ammoRequests") select 0 get "collectAt") - 5.25) < 0.001,"fractional arrival fixes collection deadline instead of restarting delay at the poll"] call _assert;
[_e,_e get "units",5.2,false] call IVCS_Ammo_updateRequests;
[(_e get "ammoTransfers") == 0,"queued virtual sharing cannot finish before its full approach and collection delays"] call _assert;
[_e,_e get "units",5.3,false] call IVCS_Ammo_updateRequests;
[(_e get "ammoTransfers") == 1,"queued virtual sharing completes at its original deadline after a delayed arrival poll"] call _assert;
[_e] call IVCS_VirtualSpace_unregisterEntity;
_e = call _make; [_e,0,0,0.25] call _reserve;
[_e,_e get "units",6,false] call IVCS_Ammo_updateRequests;
[(_e get "ammoTransfers") == 1,"a virtual poll after both delays completes the already elapsed timeline"] call _assert;
[_e] call IVCS_VirtualSpace_unregisterEntity;

diag_log format ["[IVCS TASK TEST] DONE passed=%1 failed=%2",_passed,_failed];
