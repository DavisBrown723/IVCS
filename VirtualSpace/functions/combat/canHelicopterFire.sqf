params ["_target","_helicopter",["_initiating",false]];
private _policy = [_helicopter] call IVCS_Combat_getHelicopterPolicy;
if !(_policy select 1) exitWith {false};
private _threat = _helicopter get "airThreat";
private _responding = !_initiating && {_threat isNotEqualTo []} && {IVCS_SimulationTime<=(_threat select 1)} && {(_threat select 2)=="" || {(_threat select 2)==(_target get "id")}};
private _proactive=(_policy select 2) && {[_helicopter,_target] call IVCS_Combat_inHelicopterAttackArea};
if (!_proactive && {!_responding}) exitWith {false};
if ((_target get "entityType")=="group" && {([_target] call IVCS_Combat_getReturnFireTargets) isEqualTo []}) exitWith {false};
private _range = (_target get "position") distance (_helicopter get "position");
private _cache = createHashMap;
private _profile = if ((_target get "entityType") == "group") then {createHashMap} else {[_target get "class"] call IVCS_Combat_getVehicleProfile};
([_helicopter] call IVCS_Combat_getReturnFireStations) findIf {
    private _turret = _x select 0;
    ((_policy select 0) == "ATTACK" || {(_turret select 0) isNotEqualTo [-1]}) && {
        ([_turret,_cache,_range,_profile,true] call IVCS_Combat_getReturnFireShot) isNotEqualTo []
    }
} != -1
