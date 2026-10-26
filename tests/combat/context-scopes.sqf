// Benchmark-only context. Numeric work sizes and paths are buffered, not live inventories.
IVCS_Perf_ContextEnabled = false;
IVCS_Perf_ContextRows = [];
IVCS_Perf_ContextDeadline = -1;
IVCS_Perf_ContextBegin = {
    params ["_name","_data"];
    private _row = [_name,_data];
    IVCS_Perf_ContextRows pushBack _row;
    _data
};
IVCS_Perf_ContextSource = {
    params ["_function","_source"];
    private _replace = {
        params ["_needle","_replacement"];
        _source = [_source,_needle,_replacement] call _replaceOnce;
    };
    switch (_function) do {
        case "IVCS_Combat_step": {
            ['private _factorState =',
             'private _shotContext = []; if (IVCS_Perf_ContextEnabled) then { _shotContext = ["ShotPreparation",[_engagement get "id",count ((_groups select 0) get "units"),count ((_groups select 1) get "units"),_engagement get "elapsed",_range,_engagement get "shots",0,0]] call IVCS_Perf_ContextBegin; }; private _factorState ='] call _replace;
            if ((_source find 'if (isNil "_factors") then {') >= 0) then {
            ['if (isNil "_factors") then {','if (isNil "_factors") then { if (_shotContext isNotEqualTo []) then { _shotContext set [7,(_shotContext select 7) + 1]; };'] call _replace;
            };
            private _end = if ((_source find '_engagement set ["shots",_shots];') >= 0) then { '_engagement set ["shots",_shots];' } else { "} forEach _shooters;
} forEach _groups;" };
            [_end,_end + ' if (_shotContext isNotEqualTo []) then { _shotContext set [5,(_engagement get "shots") - (_shotContext select 5)]; _shotContext set [6,count _hits]; };'] call _replace;
        };
        case "IVCS_Combat_getPreparedShot": {
            ['[_ammo,[_weapon,_ammo,_range] call IVCS_Combat_getShotFactors]',
             'if (!isNil "_shotContext" && { _shotContext isNotEqualTo [] }) then { _shotContext set [7,(_shotContext select 7) + 1]; }; [_ammo,[_weapon,_ammo,_range] call IVCS_Combat_getShotFactors]'] call _replace;
        };
        case "IVCS_Combat_onFrame": {
            ['private _searchFirst = diag_frameNo mod 2 == 0;','IVCS_Perf_ContextDeadline = _deadline; if (IVCS_Perf_ContextEnabled) then { ["Scheduler",[count _queue,count ((_combat get "ammoSharing") get "searchQueue"),_budget,diag_frameNo mod 2 == 0]] call IVCS_Perf_ContextBegin; }; private _searchFirst = diag_frameNo mod 2 == 0;'] call _replace;
        };
        case "IVCS_Ammo_searchOnFrame": {
            ['params [["_deadline",-1]];','params [["_deadline",-1]]; private _ivcsContextSearchOrigin = "queued";'] call _replace;
        };
        case "IVCS_Ammo_updateGroup": {
            if ((_source find "private _needed =") >= 0) then {
            ['private _needed = _units apply {','private _needsContext = []; if (IVCS_Perf_ContextEnabled) then { _needsContext = ["AmmoNeedsScan",[_entity get "id",count _units,count _requests,_native,0]] call IVCS_Perf_ContextBegin; }; private _needed = _units apply {'] call _replace;
            ['if (_recipients isNotEqualTo []) then {','if (_needsContext isNotEqualTo []) then { _needsContext set [4,count _recipients]; }; if (_recipients isNotEqualTo []) then {'] call _replace;
            };
            private _inline = if ((_source find '[_entity,_now,if (_deferSearch)') >= 0) then { '[_entity,_now,if (_deferSearch)' } else { '[_entity,_now,_limit]' };
            [_inline,'private _ivcsContextSearchOrigin = "inline"; ' + _inline] call _replace;
        };
        case "IVCS_Ammo_scanNeeds": {
            ['private _cursor =', 'private _needsContext = []; if (IVCS_Perf_ContextEnabled) then { _needsContext = ["AmmoNeedsScan",[_entity get "id",0,count _requests,_native,count _recipients]] call IVCS_Perf_ContextBegin; }; private _cursor ='] call _replace;
            ['_job set ["scanIndex",_end];', 'if (_needsContext isNotEqualTo []) then { _needsContext set [1,_end - _cursor]; _needsContext set [4,count _recipients - (_needsContext select 4)]; }; _job set ["scanIndex",_end];'] call _replace;
        };
        case "IVCS_Ammo_advanceSearch": {
            ['private _operationScope = createProfileScope "IVCS_OP_DonorSlice";', 'private _operationScope = createProfileScope "IVCS_OP_DonorSlice"; private _ctx = []; if (IVCS_Perf_ContextEnabled) then { _ctx = ["DonorSlice",[_entity get "id",if (isNil "_ivcsContextSearchOrigin") then { "direct" } else { _ivcsContextSearchOrigin },_limit,_job get "recipientIndex",_job get "weaponIndex",_job get "donorIndex",count (_job get "donors"),_job get "donorIndex",count (_entity get "ammoRequests"),0]] call IVCS_Perf_ContextBegin; };'] call _replace;
            ['if ((_job get "recipientIndex") >= count _recipients) then {', 'if (_ctx isNotEqualTo []) then { _ctx set [7,_job get "donorIndex"]; _ctx set [9,count (_entity get "ammoRequests") - (_ctx select 8)]; }; if ((_job get "recipientIndex") >= count _recipients) then {'] call _replace;
            ['private _donorScope = createProfileScope "IVCS_OP_DonorInventory";',
             'private _donorScope = createProfileScope "IVCS_OP_DonorInventory"; if (IVCS_Perf_ContextEnabled) then { ["DonorInventory",[_entity get "id",_donor get "id",_donor get "class",count (_donor get "weapons"),count (_donor get "magazineCargo"),count _compatible]] call IVCS_Perf_ContextBegin; };'] call _replace;
        };
        case "IVCS_Ammo_updateRequests": {
            ['private _request = _x;', 'private _request = _x; private _requestContext = []; if (IVCS_Perf_ContextEnabled) then { _requestContext = ["PendingRequest",[_entity get "id",(_request get "recipient") get "id",_request get "phase",_native,false,false,(_request get "arriveAt") - _now,(_request get "collectAt") - _now]] call IVCS_Perf_ContextBegin; };'] call _replace;
            ['if (_valid && { _waiting }) then {','if (_requestContext isNotEqualTo []) then { _requestContext set [4,_waiting]; _requestContext set [5,_valid]; }; if (_valid && { _waiting }) then {'] call _replace;
        };
        case "IVCS_Ammo_getNeededWeapons": {
            ['params ["_unit",["_native",false]];', 'params ["_unit",["_native",false]]; private _needContext = []; if (IVCS_Perf_ContextEnabled) then { _needContext = ["UnitAmmoNeed",[_unit get "id",_unit get "class",_native,(_unit get "weapons") apply { [_x select 0,count (_x select 1)] },count (_unit get "magazineCargo"),0,[],if (isNil "_entity") then { "" } else { _entity get "id" }]] call IVCS_Perf_ContextBegin; };'] call _replace;
            private _end = if ((_source find 'if (_primary in _wanted) then {') >= 0 && { (_source find '} forEach _weapons;
if (_primary in _wanted)') >= 0 }) then { '} forEach _weapons;
if (_primary in _wanted) then { _wanted = [_primary] + (_wanted - [_primary]); };
_wanted' } else { '} forEach _weapons;
_wanted' };
            [_end,(_end select [0,count _end - count "_wanted"]) + 'if (_needContext isNotEqualTo []) then { _needContext set [6,_wanted]; };
_wanted'] call _replace;
            ['private _hasAmmo = _records findIf {
            (_x select 1) > 0 && { _compatible getOrDefault [_x select 0, false] }
        } != -1;',
             'private _hasAmmo = call { private _caseScope = createProfileScope "IVCS_CASE_NeedOwnRecords"; _records findIf {
            (_x select 1) > 0 && { _compatible getOrDefault [_x select 0, false] }
        } != -1; };'] call _replace;
            ['_hasAmmo = (_unit get "magazineCargo") findIf {',
             'private _caseScope = createProfileScope "IVCS_CASE_NeedFallback"; if (_needContext isNotEqualTo []) then { _needContext set [5,(_needContext select 5) + 1]; }; _hasAmmo = (_unit get "magazineCargo") findIf {'] call _replace;
        };
    };
    _source
};
IVCS_Perf_ContextWrap = {
    params ["_function","_saved"];
    private _before = "";
    private _after = "";
    switch (_function) do {
        case "IVCS_Combat_update": {
            _before = 'private _ctx = []; if (IVCS_Perf_ContextEnabled) then { private _eng = _this select 0; private _dt = (_this select 1) - (_eng get "lastUpdate"); _ctx = ["ExchangeVisit",[_eng get "id",_eng get "mode",_eng get "pending",_dt,1000 * (IVCS_Perf_ContextDeadline - diag_tickTime),_eng get "elapsed",0]] call IVCS_Perf_ContextBegin; };';
            _after = 'if (_ctx isNotEqualTo []) then { _ctx set [6,((_this select 0) get "elapsed") - (_ctx select 5)]; };';
        };
        case "IVCS_Ammo_surplus": {
            _before = 'private _ctx = []; if (IVCS_Perf_ContextEnabled) then { private _snapshot = _this select 0; _ctx = ["Surplus",[count (_snapshot select 2),count (_snapshot select 3),0]] call IVCS_Perf_ContextBegin; };';
            _after = 'if (_ctx isNotEqualTo []) then { _ctx set [2,count _result]; };';
        };
    };
    if (_before == "") exitWith { _saved };
    private _contextSaved = "IVCS_Perf_ContextOriginal_" + _function;
    missionNamespace setVariable [_contextSaved,compile (_before + format [' private _result = _this call %1; ',_saved] + _after + ' _result')];
    _contextSaved
};
// Classify the existing cache read without an extra function layer or duplicate lookup.
IVCS_Perf_InstallContextCacheScope = {
    private _source = preprocessFileLineNumbers "IVCS\VirtualSpace\functions\ammo\getWeaponProfile.sqf";
    _source = [_source,'private _profile = IVCS_Ammo_WeaponProfiles get _class;', 'private _profile = IVCS_Ammo_WeaponProfiles get _class; private _cacheScope = createProfileScope (if (isNil "_profile") then { "IVCS_CASE_WeaponProfileMiss" } else { "IVCS_CASE_WeaponProfileHit" });'] call _replaceOnce;
    IVCS_Ammo_getWeaponProfile = compile _source;
};
