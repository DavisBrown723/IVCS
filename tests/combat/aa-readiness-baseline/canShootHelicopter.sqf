// Virtual ledgers stop changing while native objects own fire and ammunition.
params ["_shooter","_helicopter",["_antiAirOnly",false]];
private _range=(_shooter get "position") distance (_helicopter get "position");
private _profile=[_helicopter get "class"] call IVCS_Combat_getVehicleProfile;
private _cache=createHashMap;
private _native=_shooter get "active";
if ((_shooter get "entityType")=="group") exitWith {
    (_shooter get "units") findIf {
        private _unit=_x;private _eligible=true;
        if (_native) then {
            private _object=_unit get "object";
            // Rifle-only groups cannot contribute support: avoid their inventory snapshots.
            _eligible=alive _object && {!_antiAirOnly || {(weapons _object) findIf {
                (([_x] call IVCS_Combat_getWeaponProfile) get "attackMuzzles") findIf {(_x select 2)==1} != -1
            } != -1}};
            if (_eligible) then {
                _unit=+_unit;
                _unit set ["weapons",[_object] call IVCS_Common_getUnitObjectLoadoutInfo];
            };
        };
        _eligible && {([_unit,_cache,_profile,_range,_antiAirOnly] call IVCS_Combat_getVehicleShot) isNotEqualTo []}
    } != -1
};
private _magazines=if (_native) then {magazinesAllTurrets [_shooter get "object",true]} else {[]};
([_shooter] call IVCS_Combat_getReturnFireStations) findIf {
    private _turret=_x select 0;
    if (_native) then {
        _turret=+_turret;
        private _path=_turret select 0;
        _turret set [1,(_shooter get "object") weaponsTurret _path];
        _turret set [2,(_magazines select {(_x select 1) isEqualTo _path}) apply {[_x select 0,_x select 2]}];
    };
    ([_turret,_cache,_range,_profile] call IVCS_Combat_getReturnFireShot) isNotEqualTo []
} != -1
