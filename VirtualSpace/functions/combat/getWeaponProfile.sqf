params ["_class"];
private _cached = IVCS_Combat_WeaponProfiles get _class;
if (!isNil "_cached") exitWith { _cached };
private _config = configFile >> "CfgWeapons" >> _class;
// Primary fire and secondary muzzles select their own deliberate-fire mode.
private _selectMode = {
    params ["_muzzle"];
    private _modes = getArray (_muzzle >> "modes");
    private _index = _modes findIf {getNumber (_muzzle >> _x >> "burst")<=1 && {isClass (_muzzle >> _x)}};
    if (_index==-1) then {_index=_modes findIf {isClass (_muzzle >> _x)}};
    if (_index==-1) then {_muzzle} else {_muzzle >> (_modes select _index)}
};
private _mode = [_config] call _selectMode;
private _dispersion = getNumber (_mode >> "dispersion") max 0.0005;
private _aiDispersion = (getNumber (_config >> "aiDispersionCoefX") max 1) max (getNumber (_config >> "aiDispersionCoefY") max 1);
private _muzzles = getArray (_config >> "muzzles");
if (_muzzles isEqualTo []) then { _muzzles = ["this"]; };
private _attackMuzzles = [];
{
    private _name = _x;
    private _muzzle = if (_name == "this") then { _config } else { _config >> _name };
    private _category = switch (_class) do {
        case "Throw": { 3 };
        case "Put": { 4 };
        default { if (getNumber (_config >> "type") == 4) then { 1 } else { if (_name == "this") then { 0 } else { 2 } } };
    };
    private _compatible = compatibleMagazines [_class,_name];
    _compatible append getArray (_muzzle >> "magazines");
    private _attack = [_name,createHashMapFromArray (_compatible apply { [_x,true] }),_category];
    if (_category==2) then {
        private _mode = [_muzzle] call _selectMode;
        private _ai = (getNumber (_muzzle >> "aiDispersionCoefX") max 1) max (getNumber (_muzzle >> "aiDispersionCoefY") max 1);
        _attack pushBack createHashMapFromArray [
            ["class",_class], ["dispersion",(getNumber (_mode >> "dispersion") max 0.0005)*_ai],
            ["interval",(getNumber (_mode >> "reloadTime") max 0.1)+((getNumber (_mode >> "aiRateOfFire") max 0.7) min 3)],
            ["initSpeed",getNumber (_muzzle >> "initSpeed")]
        ];
    };
    _attackMuzzles pushBack _attack;
} forEach _muzzles;
private _byMagazine = createHashMap;
{
    private _muzzle = _x;
    { if !(_x in _byMagazine) then {_byMagazine set [_x,_muzzle]}; } forEach keys (_muzzle select 1);
} forEach _attackMuzzles;
// Capability probes need compatibility and fuse range, not a prepared firing attempt.
// These are immutable class properties; current magazines and rounds stay on the unit.
private _antiAirMagazines=createHashMap;
{
    if ((_y select 2)==1) then {
        private _ammo=[_x] call IVCS_Combat_getAmmoProfile;
        if (_ammo get "vehicleSupported" && {(_ammo get "airLock")>0}) then {
            _antiAirMagazines set [_x,_ammo get "fuseDistance"];
        };
    };
} forEach _byMagazine;
private _profile = createHashMapFromArray [
    ["attackByMagazine",_byMagazine],
    ["antiAirMagazines",_antiAirMagazines],
    ["smallArmsOnly",count _attackMuzzles == 1 && {(_attackMuzzles select 0 select 2)==0}],
    ["attackMuzzles",_attackMuzzles],
    ["class", _class],
    ["launcher",getNumber (_config >> "type") == 4],
    ["compatible",createHashMapFromArray ((([_class] call IVCS_Common_getWeaponInfo) select 2) apply { [_x,true] })],
    ["supported", getNumber (_config >> "type") in [1, 2]],
    ["dispersion", _dispersion * _aiDispersion],
    ["interval", (getNumber (_mode >> "reloadTime") max 0.1) + ((getNumber (_mode >> "aiRateOfFire") max 0.7) min 3)],
    ["initSpeed", getNumber (_config >> "initSpeed")]
];
IVCS_Combat_WeaponProfiles set [_class, _profile];
_profile
