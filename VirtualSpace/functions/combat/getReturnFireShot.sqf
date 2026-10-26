// Select one compatible weapon per station. Pylons keep their identity and round field.
params ["_turret","_cache","_range",["_targetProfile",createHashMap],["_pylons",false]];
private _combat = IVCS_VirtualSpace_Controller get "combat";
private _vehicleTarget = count _targetProfile>0;
private _airTarget = _vehicleTarget && {(_targetProfile get "kind")=="air"};
private _armored = _vehicleTarget && {_targetProfile get "armored"};
private _weapons = +(_turret select 1);
private _sources = [[_turret select 2,0,1,true]];
if (_pylons) then {
    _sources pushBack [_turret select 3,1,2,false];
    {if ((_x select 1)!="") then {_weapons pushBackUnique getText (configFile >> "CfgMagazines" >> (_x select 1) >> "pylonWeapon")}} forEach (_turret select 3);
};
private _best = []; private _bestRank = 2;
{
    private _class = _x;
    private _state = _cache get _class;
    if (isNil "_state") then {_state=[[_class] call IVCS_Combat_getTurretWeaponProfile,createHashMap];_cache set [_class,_state]};
    (_state select 0) params ["_weapon","_byMagazine"];
    private _preparedCache = _state select 1;
    {
        _x params ["_records","_magIndex","_roundIndex","_remove"];
        {
            private _record = _x;
            if ((_record select _roundIndex)>0) then {
                private _magazine = _record select _magIndex;
                private _prepared = _preparedCache get _magazine;
                if (isNil "_prepared") then {
                    _prepared=[];
                    private _data = _byMagazine get _magazine;
                    if (!isNil "_data") then {
                        _data params ["_ammo","_modes"];
                        private _suitable = if (!_vehicleTarget) then {_ammo get "infantrySupported"} else {
                            if (_airTarget) then {_ammo get "airSupported"} else {
                                _ammo get "groundSupported" && {!_armored || {_ammo get "antiArmor"}}
                            }
                        };
                        private _mode=[];private _score=-1;
                        if (_suitable) then {
                            {
                                _x params ["_min","_minP","_mid","_midP","_max","_maxP"];
                                if (_max==0 || {_range>=_min && {_range<=_max}}) then {
                                    private _prob = if (_max==0) then {1} else {
                                        if (_range<=_mid) then {_minP+(_midP-_minP)*((_range-_min)/((_mid-_min) max 0.001))} else {_midP+(_maxP-_midP)*((_range-_mid)/((_max-_mid) max 0.001))}
                                    };
                                    if (_prob>_score) then {_score=_prob;_mode=_x};
                                };
                            } forEach _modes;
                        };
                        if (_mode isNotEqualTo []) then {
                            private _firingWeapon = createHashMapFromArray [["class",_weapon get "class"],["initSpeed",_weapon get "initSpeed"],["dispersion",_mode select 10]];
                            private _factors = [_firingWeapon,_ammo,_range] call IVCS_Combat_getShotFactors;
                            if !(_ammo get "bullet") then {_factors set [1,1]};
                            if (_vehicleTarget) then {
                                private _spread=(_firingWeapon get "dispersion")*_range/((_targetProfile get "size")/2);
                                private _falloff=_range/(if (_ammo get "guided") then {1200} else {600});
                                _factors set [0,(_combat get "accuracyScale")*0.75/(1+_falloff^2+_spread^2)];
                            };
                            private _burst = _mode select 6;
                            private _pause = (_mode select 8) * ((_range/(_mode select 9)) min 1);
                            private _interval = (((_mode select 7)+_pause/_burst)*(_combat get "cadenceScale")) max ((_combat get "minimumFireInterval")/_burst);
                            private _rank = if (_vehicleTarget) then {if (_ammo get "antiArmor") then {0} else {1}} else {if (_ammo get "bullet") then {0} else {1}};
                            private _directAmmo=_ammo;
                            if (!_vehicleTarget && {(_ammo get "blast")>(_ammo get "hit")*(_factors select 1)}) then {
                                _directAmmo=+_ammo;_directAmmo set ["hit",_ammo get "blast"];_factors set [1,1];
                            };
                            _prepared=[_firingWeapon,_directAmmo,_factors,_interval,_rank];
                        };
                    };
                    _preparedCache set [_magazine,_prepared];
                };
                if (_prepared isNotEqualTo [] && {_range>=((_prepared select 1) get "fuseDistance")} && {(_prepared select 4)<_bestRank}) then {
                    _bestRank=_prepared select 4;
                    _best=[_record,_prepared select 0,_prepared select 1,_prepared select 2,_prepared select 3,_records,_forEachIndex,_roundIndex,_remove];
                };
            };
            if (_bestRank==0) exitWith {};
        } forEach _records;
        if (_bestRank==0) exitWith {};
    } forEach _sources;
    if (_bestRank==0) exitWith {};
} forEach _weapons;
_best
