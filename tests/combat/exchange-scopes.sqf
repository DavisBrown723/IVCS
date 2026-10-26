// Deeper diagnostic scopes supplement resolution-scopes; all context flushes outside the root.
IVCS_ExchangeDiag_Step=IVCS_Combat_step;
IVCS_Combat_step={
    params ["_engagement"];
    private _ctx=["exchange",diag_frameNo,_engagement get "id",_engagement get "seed",_engagement get "stepTime",_engagement get "shots",_engagement get "hits",_engagement get "vehicleShots",_engagement get "startedAt"];
    IVCS_ResolutionDiag_Rows pushBack _ctx;
    private _result=_this call IVCS_ExchangeDiag_Step;
    _ctx append [_engagement get "seed",_engagement get "shots",_engagement get "hits",_engagement get "vehicleShots"];
    _result
};
private _source=preprocessFileLineNumbers "IVCS\VirtualSpace\functions\combat\getReturnFireStations.sqf";
_source=[_source,'private _assignment =','private _scope=createProfileScope "IVCS_EX_OperatorVisit"; private _assignment ='] call _replaceOnce;
_source=[_source,'private _path = str','private _scope=createProfileScope "IVCS_EX_StationVisit"; private _path = str'] call _replaceOnce;
IVCS_Combat_getReturnFireStations=compile _source;
_source=preprocessFileLineNumbers "IVCS\VirtualSpace\functions\combat\stepVehicle.sqf";
_source=[_source,'private _unit = _x;','private _scope=createProfileScope "IVCS_RES_InfantryShooter";private _unit = _x;'] call _replaceOnce;
_source=[_source,'_state = [_settings,createHashMap];','IVCS_ResolutionDiag_Rows pushBack ["factorMiss",diag_frameNo,_infantry get "id",_range,_supportOnly];_state = [_settings,createHashMap];'] call _replaceOnce;
_source=[_source,'_shot params','private _fireScope=createProfileScope "IVCS_EX_InfantryAttempts";_shot params'] call _replaceOnce;
_source=[_source,'_x call IVCS_Combat_damageVehicle;','call {private _scope=createProfileScope "IVCS_EX_ApplyInfantryImpact";_x call IVCS_Combat_damageVehicle};'] call _replaceOnce;
IVCS_Combat_stepVehicle=compile _source;
_source=preprocessFileLineNumbers "IVCS\VirtualSpace\functions\combat\damageVehicle.sqf";
_source=[_source,'private _profile =','IVCS_ResolutionDiag_Rows pushBack ["damage",diag_frameNo,_vehicle get "class",_ammo get "class",_factor];private _profile ='] call _replaceOnce;
_source=[_source,'if (!isNil "_calibrated") then {','if (!isNil "_calibrated") then {private _scope=createProfileScope "IVCS_EX_CalibratedDamage";'] call _replaceOnce;
_source=[_source,'_increment = (_ammo get "vehicleHit")','private _scope=createProfileScope "IVCS_EX_FallbackDamage";_increment = (_ammo get "vehicleHit")'] call _replaceOnce;
IVCS_Combat_damageVehicle=compile _source;
_source=preprocessFileLineNumbers "IVCS\VirtualSpace\functions\combat\damageCrew.sqf";
_source=[_source,'private _group =','private _ownerScope=createProfileScope "IVCS_EX_CrewOwner";private _group ='] call _replaceOnce;
_source=[_source,'private _unit = _x;','private _scope=createProfileScope "IVCS_RES_Occupant";private _unit = _x;'] call _replaceOnce;
_source=[_source,'if (_injury > 0) then {','if (_injury > 0) then {private _scope=createProfileScope "IVCS_RES_CrewInjury";'] call _replaceOnce;
IVCS_Combat_damageCrew=compile _source;
{
    private _saved="IVCS_ExchangeDiag_"+_x;
    missionNamespace setVariable [_saved,missionNamespace getVariable _x];
    missionNamespace setVariable [_x,compile format ['private _scope=createProfileScope %1;_this call %2',str ("IVCS_EX_"+_x),_saved]];
} forEach ["IVCS_VirtualSpace_getEntity","IVCS_Combat_mountState","IVCS_Combat_getShotFactors","IVCS_Combat_getUnitProfile","IVCS_Combat_canHelicopterFire"];
diag_log "[IVCS PERF] EXCHANGE_SCOPES installed";
