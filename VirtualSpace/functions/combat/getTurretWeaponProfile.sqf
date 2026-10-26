// Immutable muzzle/mode/ammunition metadata, prepared when a vehicle is created.
params ["_class"];
private _cached = IVCS_Combat_TurretWeaponProfiles get _class;
if (!isNil "_cached") exitWith {_cached};
private _config = configFile >> "CfgWeapons" >> _class;
private _base = [_class] call IVCS_Combat_getWeaponProfile;
private _muzzles = getArray (_config >> "muzzles");
if (_muzzles isEqualTo []) then {_muzzles=["this"]};
private _magazines = createHashMap;
{
    private _muzzle = if (_x=="this") then {_config} else {_config >> _x};
    private _names = getArray (_muzzle >> "modes");
    if (_names isEqualTo []) then {_names=["this"]};
    private _modes = _names apply {if (_x=="this") then {_muzzle} else {_muzzle >> _x}};
    private _ai = _modes select {getNumber (_x >> "showToPlayer")==0};
    if (_ai isNotEqualTo []) then {_modes=_ai};
    private _prepared = _modes apply {
        [getNumber (_x >> "minRange"),getNumber (_x >> "minRangeProbab"),
         getNumber (_x >> "midRange"),getNumber (_x >> "midRangeProbab"),
         getNumber (_x >> "maxRange"),getNumber (_x >> "maxRangeProbab"),
         getNumber (_x >> "burst") max 1,getNumber (_x >> "reloadTime") max 0.01,
         getNumber (_x >> "aiRateOfFire") max 0,getNumber (_x >> "aiRateOfFireDistance") max 1,
         (getNumber (_x >> "dispersion") max 0.0005) * ((getNumber (_config >> "aiDispersionCoefX") max 1) max (getNumber (_config >> "aiDispersionCoefY") max 1))]
    };
    private _compatible = (compatibleMagazines [_class,_x]) + getArray (_muzzle >> "magazines");
    {
        private _ammo = [_x] call IVCS_Combat_getAmmoProfile;
        if (_ammo get "mountedSupported") then {_magazines set [_x,[_ammo,_prepared]]};
    } forEach (_compatible arrayIntersect _compatible);
} forEach _muzzles;
_cached = [_base,_magazines];
IVCS_Combat_TurretWeaponProfiles set [_class,_cached];
_cached
