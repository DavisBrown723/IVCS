// The engagement cache holds class metadata and factors, never inventory contents.
params ["_unit","_cache","_range","_cadenceScale","_minimumInterval"];
private _result = [];
(_unit get "weapons") findIf {
    _x params ["_weaponClass","_magazines"];
    private _weaponState = _cache get _weaponClass;
    if (isNil "_weaponState") then {
        private _weapon = [_weaponClass] call IVCS_Combat_getWeaponProfile;
        _weaponState = [_weapon,createHashMap,((_weapon get "interval") * _cadenceScale) max _minimumInterval];
        _cache set [_weaponClass,_weaponState];
    };
    private _weapon = _weaponState select 0;
    _weapon get "supported" && {
        private _ammoCache = _weaponState select 1;
        private _prepared = [];
        private _index = _magazines findIf {
            (_x select 1) > 0 && {
                private _class = _x select 0;
                _prepared = _ammoCache get _class;
                if (isNil "_prepared") then {
                    private _ammo = [_class] call IVCS_Combat_getAmmoProfile;
                    _prepared = if (_ammo get "supported") then {
                        [_ammo,[_weapon,_ammo,_range] call IVCS_Combat_getShotFactors]
                    } else { [] };
                    _ammoCache set [_class,_prepared];
                };
                _prepared isNotEqualTo []
            }
        };
        if (_index != -1) then {
            // Owner/index are fresh per selection, never stored in the class-factor cache.
            _result = [_magazines select _index,_weapon,_prepared select 0,_prepared select 1,_weaponState select 2,_magazines,_index];
        };
        _index != -1
    }
};
_result
