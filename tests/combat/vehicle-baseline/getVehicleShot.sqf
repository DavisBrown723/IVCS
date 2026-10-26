// Cache suitability/factors by class, but read rounds and source indices every time.
params ["_unit","_cache","_targetProfile","_range"];
private _result = [];
(_unit get "weapons") findIf {
    _x params ["_weaponClass","_magazines"];
    private _state = _cache get _weaponClass;
    if (isNil "_state") then {
        private _weapon = [_weaponClass] call IVCS_Combat_getWeaponProfile;
        private _settings = IVCS_VirtualSpace_Controller get "combat";
        _state = [_weapon,createHashMap,((_weapon get "interval") * (_settings get "cadenceScale")) max (_settings get "minimumFireInterval")];
        _cache set [_weaponClass,_state];
    };
    _state params ["_weapon","_ammoCache","_interval"];
    (_weapon get "supported" || { _weapon get "launcher" }) && {
        private _prepared = [];
        private _index = _magazines findIf {
            (_x select 1) > 0 && { (_weapon get "compatible") getOrDefault [_x select 0,false] } && {
                private _class = _x select 0;
                _prepared = _ammoCache get _class;
                if (isNil "_prepared") then {
                    private _ammo = [_class] call IVCS_Combat_getAmmoProfile;
                    private _suitable = if (_weapon get "launcher") then {
                        _ammo get "vehicleSupported" && { !(_targetProfile get "armored") || { _ammo get "penetrator" } }
                    } else { _ammo get "supported" && { !(_targetProfile get "armored") } };
                    _prepared = [];
                    if (_suitable) then {
                        private _guided = _ammo get "guided";
                        private _spread = (_weapon get "dispersion") * _range / ((_targetProfile get "size") / 2);
                        private _falloff = _range / (if (_guided) then { 600 } else { 300 });
                        private _accuracy = ((IVCS_VirtualSpace_Controller get "combat") get "accuracyScale") * 0.75 / (1 + _falloff^2 + _spread^2);
                        private _damageFactor = if (_weapon get "launcher") then { 1 } else { ([_weapon,_ammo,_range] call IVCS_Combat_getShotFactors) select 1 };
                        _prepared = [_ammo,[_accuracy,_damageFactor]];
                    };
                    _ammoCache set [_class,_prepared];
                };
                _prepared isNotEqualTo []
            }
        };
        if (_index != -1) then { _result = [_magazines select _index,_weapon,_prepared select 0,_prepared select 1,_interval,_magazines,_index]; };
        _index != -1
    }
};
_result
