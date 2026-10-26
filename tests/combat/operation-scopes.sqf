// Installed only in the isolated profiler benchmark. Production files remain unchanged.
// Fail on changed/ambiguous anchors rather than silently measuring the wrong block.
private _replaceOnce = {
    params ["_source","_needle","_replacement"];
    _source = toString ((toArray _source) select { _x != 13 });
    _needle = toString ((toArray _needle) select { _x != 13 });
    _replacement = toString ((toArray _replacement) select { _x != 13 });
    private _index = _source find _needle;
    if (_index < 0 || { ((_source select [_index + count _needle]) find _needle) >= 0 }) then {
        throw format ["Operation scope anchor missing or ambiguous: %1",_needle];
    };
    (_source select [0,_index]) + _replacement + (_source select [_index + count _needle])
};
private _source = preprocessFileLineNumbers "IVCS\VirtualSpace\functions\combat\step.sqf";
_source = [_source,"private _factorState =",'call { private _operationScope = createProfileScope "IVCS_OP_ShotPreparation"; private _factorState ='] call _replaceOnce;
_source = [_source,"private _unit = _x;",'private _unitScope = createProfileScope "IVCS_OP_ShooterVisit"; private _unit = _x;'] call _replaceOnce;
if ((_source find "private _attempts =") >= 0) then {
    private _armRead = 'private _armDamage = 0;
                private _hitpoints = _unit get "hitpoints";
                { _armDamage = _armDamage max (_hitpoints select _x select 1); } forEach (([_unit] call IVCS_Combat_getHitpointLayout) select 2);';
    _source = [_source,_armRead,'private _armDamage = call { private _armScope = createProfileScope "IVCS_OP_ArmDamage"; ' + _armRead + ' _armDamage; };'] call _replaceOnce;
} else {
    if ((_source find "private _armDamage = 0;") >= 0) then {
        _source = [_source,"private _armDamage = 0;",'private _accuracy = call { private _accuracyScope = createProfileScope "IVCS_OP_Accuracy"; private _armDamage = 0;'] call _replaceOnce;
        _source = [_source,'private _accuracy = (((_factors select 0) * (1 - 0.65 * _armDamage)) max 0) min 0.8;', '(((_factors select 0) * (1 - 0.65 * _armDamage)) max 0) min 0.8; };'] call _replaceOnce;
    };
};
_source = [_source,'_engagement set ["hits",','}; call { private _operationScope = createProfileScope "IVCS_OP_DamageApplication"; _engagement set ["hits",'] call _replaceOnce;
_source = [_source,"{ _x call IVCS_Combat_damageUnit; } forEach _hits;",'{ _x call IVCS_Combat_damageUnit; } forEach _hits; }; call { private _operationScope = createProfileScope "IVCS_OP_CasualtyCleanup";'] call _replaceOnce;
_source = [_source,'_engagement set ["elapsed",','}; _engagement set ["elapsed",'] call _replaceOnce;
if (!isNil "IVCS_Perf_ContextSource") then { _source = ["IVCS_Combat_step",_source] call IVCS_Perf_ContextSource; };
IVCS_Combat_step = compile _source;
_source = preprocessFileLineNumbers "IVCS\VirtualSpace\functions\ammo\updateGroup.sqf";
_source = [_source,"isNil {",'isNil { private _operationScope = createProfileScope "IVCS_OP_AmmoScan";'] call _replaceOnce;
if ((_source find "private _needed =") >= 0) then {
    _source = [_source,'if ((_entity get "ammoSearch") isEqualTo []) then {','if ((_entity get "ammoSearch") isEqualTo []) then { private _needsScope = createProfileScope "IVCS_OP_AmmoNeedsScan";'] call _replaceOnce;
};
if (!isNil "IVCS_Perf_ContextSource") then { _source = ["IVCS_Ammo_updateGroup",_source] call IVCS_Perf_ContextSource; };
IVCS_Ammo_updateGroup = compile _source;
_source = preprocessFileLineNumbers "IVCS\VirtualSpace\functions\ammo\advanceSearch.sqf";
_source = [_source,'private _native = _job get "native";','private _operationScope = createProfileScope "IVCS_OP_DonorSlice"; private _native = _job get "native";'] call _replaceOnce;
_source = [_source,'params ["_donor","_compatible"];','params ["_donor","_compatible"]; private _donorScope = createProfileScope "IVCS_OP_DonorInventory";'] call _replaceOnce;
_source = [_source,'private _hadCandidate = _best isNotEqualTo [];' ,'private _hadCandidate = _best isNotEqualTo []; call { private _winnerScope = createProfileScope "IVCS_OP_WinnerRevalidation";' ] call _replaceOnce;
_source = [_source,'if (_best isNotEqualTo []) then {
                        [_entity,_recipient,_donor,_weapon,_best,_now,_native] call IVCS_Ammo_createRequest;', '}; if (_best isNotEqualTo []) then {
                        [_entity,_recipient,_donor,_weapon,_best,_now,_native] call IVCS_Ammo_createRequest;'] call _replaceOnce;
if (!isNil "IVCS_Perf_ContextSource") then { _source = ["IVCS_Ammo_advanceSearch",_source] call IVCS_Perf_ContextSource; };
IVCS_Ammo_advanceSearch = compile _source;
_source = preprocessFileLineNumbers "IVCS\VirtualSpace\functions\ammo\updateRequests.sqf";
_source = [_source,"private _request = _x;",'private _requestScope = createProfileScope "IVCS_OP_PendingRequest"; private _request = _x;'] call _replaceOnce;
if (!isNil "IVCS_Perf_ContextSource") then { _source = ["IVCS_Ammo_updateRequests",_source] call IVCS_Perf_ContextSource; };
IVCS_Ammo_updateRequests = compile _source;
if (!isNil "IVCS_Perf_ContextSource") then {
    {
        _x params ["_function","_path"];
        private _source = preprocessFileLineNumbers _path;
        private _destination = if (_function == "IVCS_Combat_onFrame" && { !isNil "IVCS_Perf_Original_IVCS_Combat_onFrame" }) then { "IVCS_Perf_Original_IVCS_Combat_onFrame" } else { _function };
        missionNamespace setVariable [_destination,compile ([_function,_source] call IVCS_Perf_ContextSource)];
    } forEach [
        ["IVCS_Combat_onFrame","IVCS\VirtualSpace\functions\combat\onFrame.sqf"],
        ["IVCS_Combat_getPreparedShot","IVCS\VirtualSpace\functions\combat\getPreparedShot.sqf"],
        ["IVCS_Ammo_searchOnFrame","IVCS\VirtualSpace\functions\ammo\searchOnFrame.sqf"],
        ["IVCS_Ammo_getNeededWeapons","IVCS\VirtualSpace\functions\ammo\getNeededWeapons.sqf"],
        ["IVCS_Ammo_scanNeeds","IVCS\VirtualSpace\functions\ammo\scanNeeds.sqf"]
    ];
};
// These include their child scopes; do not sum inclusive parents and children.
{
    _x params ["_function","_name"];
    private _original = missionNamespace getVariable _function;
    private _saved = "IVCS_Perf_OperationOriginal_" + _function;
    missionNamespace setVariable [_saved,_original];
    if (!isNil "IVCS_Perf_ContextWrap") then { _saved = [_function,_saved] call IVCS_Perf_ContextWrap; };
    missionNamespace setVariable [_function,compile format ['private _operationScope = createProfileScope %1; _this call %2;',str ("IVCS_OP_" + _name),_saved]];
} forEach [
    ["IVCS_Combat_update","ExchangeVisit"],
    ["IVCS_Combat_getShot","GetShot"],
    ["IVCS_Combat_getPreparedShot","GetShot"],
    ["IVCS_Combat_accuracy","Accuracy"],
    ["IVCS_Combat_sampleHits","BinomialSampling"],
    ["IVCS_Combat_damageUnit","DamageUnit"],
    ["IVCS_Combat_isInfantry","InfantryQualification"],
    ["IVCS_Combat_canSee","Visibility"],
    ["IVCS_Ammo_updateGroup","AmmoGroupVisit"],
    ["IVCS_Ammo_getNeededWeapons","UnitAmmoNeed"],
    ["IVCS_Ammo_updateRequests","PendingRequests"],
    ["IVCS_Ammo_advanceSearch","DiscoverySlice"],
    ["IVCS_Ammo_scanNeeds","AmmoNeedsScan"],
    ["IVCS_Ammo_snapshot","InventorySnapshot"],
    ["IVCS_Ammo_surplus","Surplus"],
    ["IVCS_Ammo_getReservedMagazine","ReservedMagazine"],
    ["IVCS_Ammo_transfer","Transfer"]
];
if (!isNil "IVCS_Perf_InstallContextCacheScope") then { call IVCS_Perf_InstallContextCacheScope; };
diag_log "[IVCS PERF] OPERATION_SCOPES installed";
