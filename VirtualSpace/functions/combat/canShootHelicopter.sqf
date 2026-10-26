// Virtual ledgers stop changing while native objects own fire and ammunition.
params ["_shooter","_helicopter",["_antiAirOnly",false]];
private _range=(_shooter get "position") distance (_helicopter get "position");
private _native=_shooter get "active";
if (_antiAirOnly && {(_shooter get "entityType")=="group"}) exitWith {
    if (_range>((IVCS_VirtualSpace_Controller get "combat") get "helicopterInfantryRange")) exitWith {false};
    private _profiles=IVCS_Combat_WeaponProfiles;
    private _units=_shooter get "units";
    private _count=count _units;
    // A previous successful index is only a search hint. Read that unit's current state,
    // then visit every other unit if it is no longer ready or the roster has changed.
    private _index=_shooter getOrDefault ["antiAirShooterIndex",0];
    if (_index>=_count) then {_index=0};
    private _found=-1;
    for "_offset" from 0 to (_count-1) do {
        private _unit=_units select _index;
        private _weapons=_unit get "weapons";
        if (_native) then {
            private _object=_unit get "object";
            // Avoid inventory snapshots for native riflemen; virtual inventories are current.
            private _eligible=(_unit get "vehicleAssignment") isEqualTo [] || {
                !(([_unit] call IVCS_Combat_mountState) in [1,4])
            };
            _weapons=if (_eligible && {alive _object} && {(weapons _object) findIf {
                count (([_x] call IVCS_Combat_getWeaponProfile) get "antiAirMagazines")>0
            } != -1}) then {[_object] call IVCS_Common_getUnitObjectLoadoutInfo} else {[]};
        };
        if ((_weapons findIf {
            private _profile=_profiles get (_x select 0);
            if (isNil "_profile") then {_profile=[_x select 0] call IVCS_Combat_getWeaponProfile};
            private _compatible=_profile get "antiAirMagazines";
            count _compatible>0 && {(_x select 1) findIf {
                (_x select 1)>0 && {
                    private _minimum=_compatible get (_x select 0);
                    !isNil "_minimum" && {_range>=_minimum}
                }
            } != -1}
        } != -1) && {
            // Seat/terrain eligibility matters only for a unit with usable AA ammunition.
            _native || {(_unit get "vehicleAssignment") isEqualTo [] || {
                !(([_unit] call IVCS_Combat_mountState) in [1,4])
            }}
        }) exitWith {_found=_index};
        _index=(_index+1) mod _count;
    };
    if (_found!=-1) then {_shooter set ["antiAirShooterIndex",_found]};
    _found!=-1
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
