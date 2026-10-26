// Virtual ledgers stop changing while native objects own fire and ammunition.
params ["_shooter","_helicopter",["_antiAirOnly",false]];
private _range=(_shooter get "position") distance (_helicopter get "position");
private _native=_shooter get "active";
if (_antiAirOnly && {(_shooter get "entityType")=="group"}) exitWith {
    if (_range>((IVCS_VirtualSpace_Controller get "combat") get "helicopterInfantryRange")) exitWith {false};
    (_shooter get "units") findIf {
        private _unit=_x;
        private _mount=if ((_unit get "vehicleAssignment") isEqualTo []) then {0} else {[_unit] call IVCS_Combat_mountState};
        private _eligible=!(_mount in [1,4]);
        private _weapons=_unit get "weapons";
        if (_native) then {
            private _object=_unit get "object";
            _eligible=_eligible && {alive _object} && {(weapons _object) findIf {
                count (([_x] call IVCS_Combat_getWeaponProfile) get "antiAirMagazines")>0
            } != -1};
            if (_eligible) then {_weapons=[_object] call IVCS_Common_getUnitObjectLoadoutInfo};
        };
        _eligible && {_weapons findIf {
            private _compatible=([_x select 0] call IVCS_Combat_getWeaponProfile) get "antiAirMagazines";
            count _compatible>0 && {(_x select 1) findIf {
                (_x select 1)>0 && {
                    private _minimum=_compatible get (_x select 0);
                    !isNil "_minimum" && {_range>=_minimum}
                }
            } != -1}
        } != -1}
    } != -1
};
private _profile=[_helicopter get "class"] call IVCS_Combat_getVehicleProfile;
private _cache=createHashMap;
if ((_shooter get "entityType")=="group") exitWith {
    (_shooter get "units") findIf {
        private _unit=_x;private _eligible=true;
        if (_native) then {
            private _object=_unit get "object";
            _eligible=alive _object;
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
