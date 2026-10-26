// One policy for engagement start and stalled-fight recovery; inventories stay live.
params ["_infantry","_vehicle"];
private _range = (_infantry get "position") distance (_vehicle get "position");
private _profile = [_vehicle get "class"] call IVCS_Combat_getVehicleProfile;
private _cache = createHashMap;
if ((_infantry get "units") findIf {([_x,_cache,_profile,_range] call IVCS_Combat_getVehicleShot) isNotEqualTo []} != -1) exitWith {true};
if (([_infantry] call IVCS_Combat_getReturnFireTargets) isEqualTo []) exitWith {false};
_cache = createHashMap;
([_vehicle] call IVCS_Combat_getReturnFireStations) findIf {([_x select 0,_cache,_range] call IVCS_Combat_getReturnFireShot) isNotEqualTo []} != -1
