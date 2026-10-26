// Diagnostic-only combat resolution scopes. Context flushes after the measured root.
private _replaceOnce={
    params ["_source","_needle","_replacement"];
    _source=toString ((toArray _source) select {_x!=13});
    _needle=toString ((toArray _needle) select {_x!=13});
    private _index=_source find _needle;
    if (_index<0 || {((_source select [_index+count _needle]) find _needle)>=0}) then {throw format ["Resolution diagnostic anchor missing/ambiguous: %1",_needle]};
    (_source select [0,_index])+_replacement+(_source select [_index+count _needle])
};
IVCS_ResolutionDiag_Rows=[];
private _source=preprocessFileLineNumbers "IVCS\VirtualSpace\functions\combat\getReturnFireShot.sqf";
_source=[_source,'private _combat =','private _ctx=["shot",diag_frameNo,_range,count _targetProfile>0,_pylons,0,0,0,0,[]]; IVCS_ResolutionDiag_Rows pushBack _ctx; private _combat ='] call _replaceOnce;
_source=[_source,'private _class = _x;','private _class = _x;_ctx set [5,(_ctx select 5)+1];'] call _replaceOnce;
_source=[_source,'private _record = _x;','private _recordScope=createProfileScope "IVCS_RES_RecordVisit"; private _record = _x;_ctx set [6,(_ctx select 6)+1];'] call _replaceOnce;
_source=[_source,'if (isNil "_prepared") then {','if (isNil "_prepared") then {private _prepareScope=createProfileScope "IVCS_RES_Prepare"; _ctx set [7,(_ctx select 7)+1];'] call _replaceOnce;
_source=[_source,'if (_prepared isNotEqualTo [] &&','if (_prepared isEqualTo []) then {_ctx set [8,(_ctx select 8)+1]}; if (_prepared isNotEqualTo [] &&'] call _replaceOnce;
_source=[_source,'_best=[_record,','_ctx set [9,[_class,_magazine]]; _best=[_record,'] call _replaceOnce;
IVCS_Combat_getReturnFireShot=compile _source;
_source=preprocessFileLineNumbers "IVCS\VirtualSpace\functions\combat\damageVehicle.sqf";
_source=[_source,'private _profile =','IVCS_ResolutionDiag_Rows pushBack ["damage",diag_frameNo,_vehicle get "class",_ammo get "class",_factor]; private _profile ='] call _replaceOnce;
IVCS_Combat_damageVehicle=compile _source;
_source=preprocessFileLineNumbers "IVCS\VirtualSpace\functions\combat\damageCrew.sqf";
_source=[_source,'private _unit = _x;','private _scope=createProfileScope "IVCS_RES_Occupant"; private _unit = _x;'] call _replaceOnce;
_source=[_source,'if (_injury > 0) then {','if (_injury > 0) then {private _scope=createProfileScope "IVCS_RES_CrewInjury";'] call _replaceOnce;
IVCS_Combat_damageCrew=compile _source;
_source=preprocessFileLineNumbers "IVCS\VirtualSpace\functions\combat\stepReturnFire.sqf";
_source=[_source,'params ["_target","_weapon","_ammo","_factors"];','params ["_target","_weapon","_ammo","_factors"];private _scope=createProfileScope "IVCS_RES_QueueInfantryHit";'] call _replaceOnce;
_source=[_source,'if (isNil "_splash") then {','if (isNil "_splash") then {private _scope=createProfileScope "IVCS_RES_SplashGeometry";'] call _replaceOnce;
IVCS_Combat_stepReturnFire=compile _source;
_source=preprocessFileLineNumbers "IVCS\VirtualSpace\functions\combat\stepMountedVehicle.sqf";
_source=[_source,'private _key = str (_turret select 0);','private _scope=createProfileScope "IVCS_RES_MountedStation";private _key = str (_turret select 0);'] call _replaceOnce;
IVCS_Combat_stepMountedVehicle=compile _source;
_source=preprocessFileLineNumbers "IVCS\VirtualSpace\functions\combat\stepVehicle.sqf";
_source=[_source,'private _unit = _x;','private _scope=createProfileScope "IVCS_RES_InfantryShooter";private _unit = _x;'] call _replaceOnce;
IVCS_Combat_stepVehicle=compile _source;
{
    private _saved="IVCS_ResolutionDiag_"+_x;
    missionNamespace setVariable [_saved,missionNamespace getVariable _x];
    missionNamespace setVariable [_x,compile format ['private _scope=createProfileScope %1; _this call %2',str ("IVCS_RES_"+_x),_saved]];
} forEach [
    "IVCS_Combat_damageCrew","IVCS_Combat_damageUnit","IVCS_Combat_updateVehicleMobility",
    "IVCS_Combat_getBodySelection","IVCS_Combat_getHitpointLayout","IVCS_Combat_sampleHits",
    "IVCS_Combat_getProtection","IVCS_Combat_getReturnFireTargets","IVCS_Combat_getAmmoProfile",
    "IVCS_Combat_getTurretWeaponProfile","IVCS_Combat_getVehicleProfile",
    "IVCS_Combat_markAirThreat","IVCS_Combat_markInfantryAirThreat","IVCS_Combat_hasCombatContact",
    "IVCS_Combat_isPair","IVCS_Ammo_updateGroup","IVCS_Combat_update"
];
diag_log "[IVCS PERF] RESOLUTION_SCOPES installed";
