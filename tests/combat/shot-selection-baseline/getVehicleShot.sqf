// One magazine-to-muzzle lookup replaces repeated scans over Throw/Put muzzles.
params ["_unit","_cache","_targetProfile","_range",["_antiAirOnly",false]];
private _mount = if ((_unit get "vehicleAssignment") isEqualTo []) then {0} else {[_unit] call IVCS_Combat_mountState};
if (_mount == 4) exitWith {[]};
private _result = [];
private _settings = IVCS_VirtualSpace_Controller get "combat";
private _air = (_targetProfile get "kind") == "air";
private _armored = _targetProfile get "armored";
private _select = {
    params ["_weaponClass","_records"];
    private _state = _cache get _weaponClass;
    if (isNil "_state") then {
        _state = [[_weaponClass] call IVCS_Combat_getWeaponProfile,createHashMap];
        _cache set [_weaponClass,_state];
    };
    _state params ["_weapon","_preparedCache"];
    if (_armored && {_weapon get "smallArmsOnly"}) exitWith {};
    if (_antiAirOnly && {(_weapon get "attackMuzzles") findIf {(_x select 2)==1} == -1}) exitWith {};
    private _muzzle = [];
    private _prepared = [];
    private _index = _records findIf {
        (_x select 1)>0 && {
            private _class = _x select 0;
            _muzzle = (_weapon get "attackByMagazine") getOrDefault [_class,[]];
            _muzzle isNotEqualTo [] && {
                _muzzle params ["_name","","_category",["_firing",_weapon]];
                private _minimum = if (_category==2) then {20} else {0};
                private _maximum = switch (_category) do {case 3:{35};case 4:{5};case 1:{if (_air) then {_settings get "helicopterInfantryRange"} else {_settings get "range"}};default{_settings get "range"}};
                _range >= _minimum && {_range <= _maximum} && {!(_mount==1 && {_category in [1,3,4]})} && {
                    _prepared = _preparedCache get _class;
                    if (isNil "_prepared") then {
                        private _ammo = [_class] call IVCS_Combat_getAmmoProfile;
                        private _suitable = switch (_category) do {
                            case 0:{!_antiAirOnly && {_ammo get "supported"} && {!_armored}};
                            case 1:{_ammo get "vehicleSupported" && {if (_air) then {(_ammo get "airLock")>0} else {(_ammo get "airLock")<2}} && {!_armored || {_ammo get "antiArmor"} || {_air}}};
                            case 2;
                            case 3:{(_ammo get "blast")>0 && {!_air && {!_armored || {_ammo get "antiArmor"}}}};
                            case 4:{((_ammo get "blast")>0 || {(_ammo get "hit")>0}) && {!_air && {!_armored || {_ammo get "antiArmor"}}}};
                            default{false};
                        };
                        _prepared=[];
                        if (_suitable) then {
                            private _spread=(_firing get "dispersion")*_range/((_targetProfile get "size")/2);
                            private _falloff=_range/(if (_ammo get "guided") then {600} else {300});
                            private _accuracy=(_settings get "accuracyScale")*0.75/(1+_falloff^2+_spread^2);
                            if (_category==3) then {_accuracy=_accuracy*0.8};
                            if (_category==4) then {_accuracy=1};
                            private _factor=if (_category==0) then {([_firing,_ammo,_range] call IVCS_Combat_getShotFactors) select 1} else {1};
                            private _interval=((_firing get "interval")*(_settings get "cadenceScale")) max (_settings get "minimumFireInterval");
                            if (_category in [2,3]) then {_interval=_interval max 4};
                            if (_category==4) then {_interval=_interval max (_settings get "placementDelay")};
                            _prepared=[_ammo,[_accuracy,_factor],_interval];
                        };
                        _preparedCache set [_class,_prepared];
                    };
                    _prepared isNotEqualTo [] && {_category==0 || {_range>=((_prepared select 0) get "fuseDistance")}}
                }
            }
        }
    };
    if (_index != -1) then {
        private _category=_muzzle select 2;
        _result=[_records select _index,_muzzle param [3,_weapon],_prepared select 0,_prepared select 1,_prepared select 2,_records,_index,_muzzle select 0,(_mount==2 || {_mount==3 && {_category in [1,3,4]}}),_category];
    };
};
(_unit get "weapons") findIf {_x call _select;_result isNotEqualTo []};
if (_result isEqualTo [] && {_range<=35} && {(_unit get "magazineCargo") isNotEqualTo []}) then {
    { if (_x!="Put" || {_range<=5}) then {[_x,_unit get "magazineCargo"] call _select};if (_result isNotEqualTo []) exitWith {}; } forEach (_unit get "utilityWeapons");
};
_result
