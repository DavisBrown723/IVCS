// Test-only nested scopes plus work counters, flushed after the measured frame closes.
private _replaceOnce={
    params ["_source","_needle","_replacement"];
    _source=toString ((toArray _source) select {_x!=13});
    _needle=toString ((toArray _needle) select {_x!=13});
    private _index=_source find _needle;
    if (_index<0 || {((_source select [_index+count _needle]) find _needle)>=0}) then {throw format ["Shot diagnostic anchor missing/ambiguous: %1",_needle]};
    (_source select [0,_index])+_replacement+(_source select [_index+count _needle])
};
IVCS_ShotDiag_Rows=[];
private _source=preprocessFileLineNumbers "IVCS\VirtualSpace\functions\combat\getVehicleShot.sqf";
_source=[_source,'private _result = [];','private _ctx=["select",diag_frameNo,_unit get "class",_range,_antiAirOnly,0,0,0,0,0,(_unit get "weapons") apply {[_x select 0,count (_x select 1)]},[]]; IVCS_ShotDiag_Rows pushBack _ctx; private _result = [];'] call _replaceOnce;
_source=[_source,'params ["_weaponClass","_records"];','params ["_weaponClass","_records"]; _ctx set [5,(_ctx select 5)+1];'] call _replaceOnce;
_source=[_source,'private _state = _cache get _weaponClass;','private _state = _cache get _weaponClass; private _weaponScope=createProfileScope (if (isNil "_state") then {"IVCS_SHOT_WeaponMiss"} else {"IVCS_SHOT_WeaponHit"});'] call _replaceOnce;
_source=[_source,'private _index = _records findIf {','private _index=call {private _scanScope=createProfileScope "IVCS_SHOT_RecordScan"; _records findIf { _ctx set [6,(_ctx select 6)+1];'] call _replaceOnce;
_source=[_source,'if (_index != -1) then {','}; if (_index != -1) then {'] call _replaceOnce;
_source=[_source,'_prepared = _preparedCache get _class;','_prepared = _preparedCache get _class; if (isNil "_prepared") then {_ctx set [7,(_ctx select 7)+1]} else {_ctx set [8,(_ctx select 8)+1]; if (_prepared isEqualTo []) then {_ctx set [9,(_ctx select 9)+1]}};'] call _replaceOnce;
_source=[_source,'if (isNil "_prepared") then {
                        private _ammo','if (isNil "_prepared") then { private _prepareScope=createProfileScope "IVCS_SHOT_Prepare";
                        private _ammo'] call _replaceOnce;
_source=[_source,'private _category=_muzzle select 2;','private _category=_muzzle select 2; _ctx set [11,[_weaponClass,(_records select _index) select 0,_category]];'] call _replaceOnce;
IVCS_Combat_getVehicleShot=compile _source;
_source=preprocessFileLineNumbers "IVCS\VirtualSpace\functions\combat\stepVehicle.sqf";
_source=[_source,'_state = [_settings,createHashMap];','private _resetScope=createProfileScope "IVCS_SHOT_CacheReset"; IVCS_ShotDiag_Rows pushBack ["reset",diag_frameNo,_infantry get "id",_range,_supportOnly]; _state = [_settings,createHashMap];'] call _replaceOnce;
_source=[_source,'private _unit = _x;','private _unitScope=createProfileScope "IVCS_SHOT_Unit"; private _unit = _x;'] call _replaceOnce;
_source=[_source,'_shot params ["_magazine"','private _fireScope=createProfileScope "IVCS_SHOT_Firing"; _shot params ["_magazine"'] call _replaceOnce;
_source=[_source,'private _count = [_attempts,_accuracy,_random] call IVCS_Combat_sampleHits;','private _count = [_attempts,_accuracy,_random] call IVCS_Combat_sampleHits; IVCS_ShotDiag_Rows pushBack ["fire",diag_frameNo,_unit get "class",_attempts,_count,_interval,_delay];'] call _replaceOnce;
IVCS_Combat_stepVehicle=compile _source;
{
    private _saved="IVCS_ShotDiag_Original_"+_x;
    missionNamespace setVariable [_saved,missionNamespace getVariable _x];
    missionNamespace setVariable [_x,compile format ['private _scope=createProfileScope %1; _this call %2',str ("IVCS_SHOT_"+_x),_saved]];
} forEach ["IVCS_Combat_sampleHits","IVCS_Combat_getHitpointLayout","IVCS_Combat_getWeaponProfile","IVCS_Combat_getAmmoProfile","IVCS_Combat_getShotFactors"];
