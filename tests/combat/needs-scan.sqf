// Compare optimized calculations against the pre-optimization resolver.
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
private _settings = (IVCS_VirtualSpace_Controller get "combat") get "ammoSharing";
private _make = {
    params [["_count",8]];
    private _units = [];
    for "_i" from 0 to (_count - 1) do {
        private _u = ["B_Soldier_F",format ["u_%1",_i]] call IVCS_VirtualSpace_Group_createUnit;
        _u set ["weapons",[["arifle_MX_F",[["30Rnd_65x39_caseless_mag",30,["infantry"]],["30Rnd_65x39_caseless_mag",30,["infantry"]]]]]];
        _u set ["magazineCargo",[]]; _units pushBack _u;
    };
    ["WEST","BLU_F",[14500,16400,0],_units] call IVCS_VirtualSpace_Group_createEntity
};
private _empty = { params ["_unit"]; (_unit get "weapons" select 0) set [1,[]]; };
private _donate = { params ["_unit"]; _unit set ["magazineCargo",[["30Rnd_65x39_caseless_mag",17,["infantry"]]]]; };
private _drain = { params ["_e",["_now",0.1]]; for "_i" from 1 to 200 do { if ((_e get "ammoSearch") isEqualTo []) exitWith {}; [_e,_now,2] call IVCS_Ammo_advanceSearch; }; };
IVCS_Needs_Original = IVCS_Ammo_getNeededWeapons; IVCS_Needs_Visited = [];
IVCS_Ammo_getNeededWeapons = { IVCS_Needs_Visited pushBack ((_this select 0) get "id"); _this call IVCS_Needs_Original; };
private _e = [32] call _make;
[_e,0] call IVCS_Ammo_updateGroup;
[count IVCS_Needs_Visited == 4 && { (_e get "ammoSearch" get "scanIndex") == 4 },"first visit reads four inventories in a large supplied roster"] call _assert;
private _frozen = (_e get "ammoSearch") get "scanUnits";
[!(_frozen isEqualRef (_e get "units")) && { (_frozen select 0) isEqualRef (_e get "units" select 0) },"roster snapshot preserves actual unit identity and has independent membership"] call _assert;
for "_i" from 1 to 6 do {
    IVCS_Needs_Visited = []; [_e,0.1,2] call IVCS_Ammo_advanceSearch;
    [count IVCS_Needs_Visited == 4 && { (_e get "ammoSearch" get "scanIndex") == 4 * (_i + 1) },"supplied scan advances exactly four current inventories per visit"] call _assert;
};
IVCS_Needs_Visited = []; [_e,0.1,0] call IVCS_Ammo_advanceSearch;
[IVCS_Needs_Visited isEqualTo [] && { (_e get "ammoSearch" get "scanIndex") == 28 },"zero work limit preserves scan cursor"] call _assert;
[_e,0.1,2] call IVCS_Ammo_advanceSearch;
[(_e get "ammoSearch") isEqualTo [] && { !((_e get "id") in (_settings get "searchQueue")) },"supplied scan completes and releases its frame queue entry"] call _assert;
[_e] call IVCS_VirtualSpace_unregisterEntity;
// A remaining unit's replacement weapon/magazine arrays must be observed.
_e = call _make; [_e,0] call IVCS_Ammo_updateGroup;
private _r = (_e get "units") select 6; [_r] call _empty; [_e get "units" select 7] call _donate;
[_e] call _drain;
[count (_e get "ammoRequests") == 1 && { (_e get "ammoRequests" select 0 get "recipient") isEqualRef _r },"later slice reads changed inventory rather than frozen contents"] call _assert;
[_e] call IVCS_VirtualSpace_unregisterEntity;
// A scanned shortage is revalidated before donor work creates a reservation.
_e = call _make; _r = (_e get "units") select 0; [_r] call _empty; [_e get "units" select 7] call _donate;
[_e,0] call IVCS_Ammo_updateGroup;
_r set ["magazineCargo",[["30Rnd_65x39_caseless_mag",11,["infantry"]]]]; [_e] call _drain;
[(_e get "ammoRequests") isEqualTo [],"pickup after observation prevents a stale reservation"] call _assert;
[_e] call IVCS_VirtualSpace_unregisterEntity;
_e = call _make; _r = (_e get "units") select 0; [_r] call _empty;
[_e,0] call IVCS_Ammo_updateGroup; [_e,_r] call IVCS_VirtualSpace_Group_RemoveUnit; [_e] call _drain;
[(_e get "ammoRequests") isEqualTo [] && { (_e get "ammoSearch") isEqualTo [] },"removed scanned recipient is excluded when the job completes"] call _assert;
[_e] call IVCS_VirtualSpace_unregisterEntity;
// New members enter the next cycle; current members keep stable identity through removals.
_e = call _make; [_e,0] call IVCS_Ammo_updateGroup;
private _new = ["B_Soldier_F","a_new"] call IVCS_VirtualSpace_Group_createUnit; [_new] call _empty;
(_e get "units") pushBack _new; [_e get "units" select 7] call _donate; [_e] call _drain;
[(_e get "ammoRequests") isEqualTo [],"new roster member waits for the next needs cycle"] call _assert;
[_e,1] call IVCS_Ammo_updateGroup; [_e,1.1] call _drain;
[count (_e get "ammoRequests") == 1 && { (_e get "ammoRequests" select 0 get "recipient") isEqualRef _new },"next cycle includes added members and their current shortage"] call _assert;
[_e] call IVCS_VirtualSpace_unregisterEntity;
_e = call _make; [_e,0] call IVCS_Ammo_updateGroup; _settings set ["enabled",false]; [_e,0.1,2] call IVCS_Ammo_advanceSearch;
[(_e get "ammoSearch") isEqualTo [] && { !((_e get "id") in (_settings get "searchQueue")) },"disabling sharing cancels a partially scanned roster"] call _assert;
_settings set ["enabled",true]; [_e] call IVCS_VirtualSpace_unregisterEntity;
IVCS_Ammo_getNeededWeapons = IVCS_Needs_Original;
private _beforeGroup = {

params ["_entity",["_now",IVCS_SimulationTime],["_deferSearch",true]];
private _settings = (IVCS_VirtualSpace_Controller get "combat") get "ammoSharing";
if (!(_settings get "enabled") || { !([_entity] call IVCS_Combat_isInfantry) }) exitWith { [_entity] call IVCS_Ammo_cancelGroup; };
if (_now < (_entity get "ammoNextScan")) exitWith {};
private _native = _entity get "active";
private _requests = _entity get "ammoRequests";
private _interval = _settings get "scanInterval";
if (_native && { _requests isNotEqualTo [] }) then { _interval = _interval min (_settings get "pendingScanInterval"); };
_entity set ["ammoNextScan",_now + _interval];
isNil {

    private _units = if (_native) then {
        (_entity get "units") select { [_x,true] call IVCS_Ammo_isEligible }
    } else { (_entity get "units") select { (_x get "damage") < 1 } };
    if (_requests isNotEqualTo []) then { [_entity,_units,_now,_native] call IVCS_Ammo_updateRequests; };
    if ((_entity get "ammoSearch") isEqualTo []) then {
        private _needed = _units apply {
            private _unit = _x;
            if (_now < (_unit get "ammoRetryAt") || { _requests findIf { (_x get "recipient") isEqualRef _unit } != -1 }) then { [] } else { [_unit,_native] call IVCS_Ammo_getNeededWeapons }
        };
        private _ordered = [];
        private _recipients = [];
        if (_needed findIf { _x isNotEqualTo [] } != -1) then {
            { _ordered pushBack [_x get "id",_forEachIndex]; } forEach _units;
            _ordered sort true;
            {
                private _index = _x select 1;
                if ((_needed select _index) isNotEqualTo []) then { _recipients pushBack [_units select _index,_needed select _index]; };
            } forEach _ordered;
        };
        if (_recipients isNotEqualTo []) then {
            _entity set ["ammoSearch",createHashMapFromArray [
                ["native",_native],["recipients",_recipients],["donors",_ordered apply { _units select (_x select 1) }],
                ["recipientIndex",0],["weaponIndex",0],["donorIndex",0],["best",[]],["bestDonor",createHashMap],["bestCount",-1]
            ]];
        };
    };
    if ((_entity get "ammoSearch") isNotEqualTo []) then {
        [_entity,_now,if (_deferSearch) then { _settings get "donorsPerSlice" } else { -1 }] call IVCS_Ammo_advanceSearch;
        if ((_entity get "ammoSearch") isNotEqualTo []) then { (_settings get "searchQueue") pushBackUnique (_entity get "id"); };
    };
    if (_native && { _requests isNotEqualTo [] }) then { (_settings get "nativeQueue") pushBackUnique (_entity get "id"); };
};

};
private _beforeAdvance = {


params ["_entity","_now","_limit"];
private _job = _entity get "ammoSearch";
if (_job isEqualTo []) exitWith {};
private _settings = (IVCS_VirtualSpace_Controller get "combat") get "ammoSharing";
if (!(_settings get "enabled") || { (_job get "native") != (_entity get "active") } || { !([_entity] call IVCS_Combat_isInfantry) }) exitWith { [_entity] call IVCS_Ammo_cancelGroup; };
isNil {
    private _native = _job get "native";
    private _units = _entity get "units";
    private _requests = _entity get "ammoRequests";
    private _recipients = _job get "recipients";
    private _donors = _job get "donors";
    private _work = 0;
    private _checkedRecipient = -1;
    private _currentWanted = [];
    private _present = {
        params ["_unit"];
        _units findIf { _x isEqualRef _unit } != -1 && {
            if (_native) then { [_unit,true] call IVCS_Ammo_isEligible } else { (_unit get "damage") < 1 }
        }
    };
    private _availableFor = {
        params ["_donor","_compatible"];
        ([[_donor,_native] call IVCS_Ammo_snapshot] call IVCS_Ammo_surplus) select {
            private _magazine = _x;
            _compatible getOrDefault [_magazine select 0,false] && { !_native || { !isNull (_magazine select 4) } } && {
                _requests findIf { (_x get "donor") isEqualRef _donor && { [_x get "token",_magazine select 3] call IVCS_Ammo_sameToken } } == -1
            }
        }
    };
    private _resetDonors = {
        _job set ["donorIndex",0]; _job set ["best",[]];
        _job set ["bestDonor",createHashMap]; _job set ["bestCount",-1];
    };
    while { (_job get "recipientIndex") < count _recipients && { _limit < 0 || { _work < _limit } } } do {
        (_recipients select (_job get "recipientIndex")) params ["_recipient","_wanted"];
        private _eligible = [_recipient] call _present && { _requests findIf { (_x get "recipient") isEqualRef _recipient } == -1 };
        if (!_eligible || { (_job get "weaponIndex") >= count _wanted }) then {
            if (_eligible) then { _recipient set ["ammoRetryAt",_now + (_settings get "retryDelay")]; };
            _job set ["recipientIndex",(_job get "recipientIndex") + 1]; _job set ["weaponIndex",0]; call _resetDonors;
        } else {
            private _weapon = _wanted select (_job get "weaponIndex");
            if (_checkedRecipient != (_job get "recipientIndex")) then {
                _currentWanted = [_recipient,_native] call IVCS_Ammo_getNeededWeapons;
                _checkedRecipient = _job get "recipientIndex";
            };
            if !(_weapon in _currentWanted) then {
                _job set ["weaponIndex",(_job get "weaponIndex") + 1]; call _resetDonors;
            } else {
                private _compatible = ([_weapon] call IVCS_Ammo_getWeaponProfile) select 2;
                if ((_job get "donorIndex") < count _donors) then {
                    private _donor = _donors select (_job get "donorIndex");
                    _job set ["donorIndex",(_job get "donorIndex") + 1];
                    if !(_donor isEqualRef _recipient) then {
                        _work = _work + 1;
                        if ([_donor] call _present) then {
                            private _available = [_donor,_compatible] call _availableFor;
                            if (count _available > (_job get "bestCount")) then {
                                private _candidate = [];
                                {
                                    if (_candidate isEqualTo [] || { (_x select 1) > (_candidate select 1) } || {
                                        (_x select 1) == (_candidate select 1) && { _native } && { (_x select 4) isEqualTo backpackContainer (_donor get "object") }
                                    }) then { _candidate = _x; };
                                } forEach _available;
                                if (_candidate isNotEqualTo []) then {
                                    _job set ["best",_candidate]; _job set ["bestDonor",_donor]; _job set ["bestCount",count _available];
                                };
                            };
                        };
                    };
                };
                if ((_job get "donorIndex") >= count _donors && { _limit < 0 || { _work < _limit } }) then {
                    private _best = _job get "best";
                    private _donor = _job get "bestDonor";
                    private _hadCandidate = _best isNotEqualTo [];

                    if (_best isNotEqualTo []) then {


                        _work = _work + 1;
                        if ([_donor] call _present) then {
                            private _token = _best select 3;
                            _best = if (_requests findIf { (_x get "donor") isEqualRef _donor && { [_x get "token",_token] call IVCS_Ammo_sameToken } } == -1) then {
                                [[_donor,_native] call IVCS_Ammo_snapshot,_token] call IVCS_Ammo_getReservedMagazine
                            } else { [] };
                            if (_best isNotEqualTo [] && {
                                !(_compatible getOrDefault [_best select 0,false]) || { _native && { isNull (_best select 4) } }
                            }) then { _best = []; };
                        } else { _best = []; };
                    };
                    if (_best isNotEqualTo []) then {
                        [_entity,_recipient,_donor,_weapon,_best,_now,_native] call IVCS_Ammo_createRequest;
                        _job set ["recipientIndex",(_job get "recipientIndex") + 1]; _job set ["weaponIndex",0];
                    } else {


                        if (!_hadCandidate) then { _job set ["weaponIndex",(_job get "weaponIndex") + 1]; };
                    };
                    call _resetDonors;
                };
            };
        };
    };
    if ((_job get "recipientIndex") >= count _recipients) then {
        _entity set ["ammoSearch",[]];
        private _index = (_settings get "searchQueue") find (_entity get "id");
        if (_index != -1) then { (_settings get "searchQueue") deleteAt _index; };
    };
};

};
private _afterAdvance = IVCS_Ammo_advanceSearch;
private _requestState = {
    params ["_e"];
    [(_e get "ammoRequests") apply { [_x get "recipient" get "id",_x get "donor" get "id",_x get "weapon",(_x get "token" select 1 select 0),(_x get "token" select 1 select 1),_x get "arriveAt"] },(_e get "units") apply { _x get "ammoRetryAt" }]
};
{
    private _count = _x;
    for "_case" from 0 to 3 do {
        private _a = [_count] call _make; private _b = [_count] call _make;
        {
            private _units = _x get "units";
            [_units select (_count - 1)] call _donate;
            if (_case > 0) then { [_units select 0] call _empty; };
            if (_case > 1) then { [_units select 2] call _empty; };
            if (_case > 2) then { reverse _units; };
        } forEach [_a,_b];
        IVCS_Ammo_advanceSearch = _beforeAdvance; [_a,0,false] call _beforeGroup;
        IVCS_Ammo_advanceSearch = _afterAdvance; [_b,0,false] call IVCS_Ammo_updateGroup;
        [([_a] call _requestState) isEqualTo ([_b] call _requestState),"batch needs priority, donor policy, partial rounds and request timing match baseline"] call _assert;
        [_a] call IVCS_VirtualSpace_unregisterEntity; [_b] call IVCS_VirtualSpace_unregisterEntity;
    };
} forEach [4,8,16];
private _beforeNeeded = {

params ["_unit",["_native",false]];
if (_native) exitWith {
    private _snapshot = [_unit,true] call IVCS_Ammo_snapshot;
    _snapshot params ["","_primary","_weapons","_magazines"];
    private _wanted = _weapons select {
        private _profile = [_x] call IVCS_Ammo_getWeaponProfile;
        private _compatible = _profile select 2;
        (_profile select 0) in [1,2,4] && { _magazines findIf { (_x select 1) > 0 && { _compatible getOrDefault [_x select 0,false] } } == -1 }
    };
    if (_primary in _wanted) then { _wanted = [_primary] + (_wanted - [_primary]); };
    _wanted
};
private _weapons = _unit get "weapons";
private _wanted = [];
private _primary = "";
{
    _x params ["_weapon", "_records"];


    private _profile = IVCS_Ammo_WeaponProfiles get _weapon;
    if (isNil "_profile") then { _profile = [_weapon] call IVCS_Ammo_getWeaponProfile; };
    private _type = _profile select 0;
    if (_primary == "" && { _type == 1 }) then { _primary = _weapon; };
    if (_type in [1,2,4]) then {
        private _compatible = _profile select 2;
        private _hasAmmo = _records findIf {
            (_x select 1) > 0 && { _compatible getOrDefault [_x select 0, false] }
        } != -1;
        if (!_hasAmmo) then {

            _hasAmmo = (_unit get "magazineCargo") findIf {
                (_x select 1) > 0 && { _compatible getOrDefault [_x select 0, false] }
            } != -1 || {
                _weapons findIf {
                    !((_x select 1) isEqualRef _records) && {
                        (_x select 1) findIf {
                            (_x select 1) > 0 && { _compatible getOrDefault [_x select 0, false] }
                        } != -1
                    }
                } != -1
            };
        };
        if (!_hasAmmo) then { _wanted pushBack _weapon; };
    };
} forEach _weapons;
if (_primary in _wanted) then { _wanted = [_primary] + (_wanted - [_primary]); };
_wanted

};
private _afterNeeded = IVCS_Ammo_getNeededWeapons;
// Direct complete supplied-group scans: includes eligibility and job bookkeeping.
private _blue = ([configFile >> "CfgGroups" >> "West" >> "BLU_F" >> "Infantry" >> "BUS_InfSquad","WEST","BLU_F",[14500,16400,0]] call IVCS_VirtualSpace_createEntity) get "group";
private _red = ([configFile >> "CfgGroups" >> "East" >> "OPF_F" >> "Infantry" >> "OIA_InfSquad","EAST","OPF_F",[14700,16400,0]] call IVCS_VirtualSpace_createEntity) get "group";
for "_trial" from 1 to 8 do {
    {
        private _group = _x; private _versions = [["before",_beforeGroup,_beforeAdvance,_beforeNeeded],["after",IVCS_Ammo_updateGroup,_afterAdvance,_afterNeeded]];
        if (_trial mod 2 == 0) then { reverse _versions; };
        {
            _x params ["_version","_fn","_advance","_needed"];
            IVCS_Ammo_advanceSearch = _advance; IVCS_Ammo_getNeededWeapons = _needed; private _elapsed = 0;
            isNil {
                private _start = diag_tickTime;
                for "_i" from 1 to 200 do { _group set ["ammoNextScan",0]; [_group,1,false] call _fn; };
                _elapsed = 1000 * (diag_tickTime - _start) / 200;
            };
            diag_log format ["[IVCS NEEDS MICRO] %1",[_trial,_group get "side",_version,_elapsed]];
        } forEach _versions;
    } forEach [_blue,_red];
};
IVCS_Ammo_advanceSearch = _afterAdvance; IVCS_Ammo_getNeededWeapons = _afterNeeded;
[_blue] call IVCS_VirtualSpace_unregisterEntity; [_red] call IVCS_VirtualSpace_unregisterEntity;
diag_log format ["[IVCS TASK TEST] DONE passed=%1 failed=%2",_passed,_failed];
