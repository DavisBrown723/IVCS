params ["_weaponClass"];

private _cachedWeaponInfo = IVCS_Common_AmmoInfo getvariable _weaponClass;
if (!isnil "_cachedWeaponInfo") exitwith { _cachedWeaponInfo };

private _weaponConfig = configfile >> "CfgWeapons" >> _weaponClass;
private _compatibleMags = getarray (_weaponConfig >> "magazines");
private _weaponLockSystem = getnumber (_weaponConfig >> "weaponLockSystem");

private _magazineInfo = [];
{
    private _magazineConfig = configfile >> "CfgMagazines" >> _x;
    private _magazineAmmo = gettext (_magazineConfig >> "ammo");
    private _ammoInfo = [_magazineAmmo] call IVCS_Common_getAmmoInfo;
    private _ammoUses = _ammoInfo select 1;

    _magazineInfo pushback [_x, _ammoUses];
} foreach _compatibleMags;

private _targetingSystems = [];
if (_weaponLockSystem != 0) then {
    private _targetingSystemFlags = _weaponLockSystem call BIS_fnc_bitflagsToArray;
    _targetingSystems = _targetingSystemFlags apply {
        switch (_x) do {
            case 1: { "visual" };
            case 2: { "ir" };
            case 4: { "laser" };
            case 8: { "radar" };
        };
    };
};

private _weaponInfo = [_weaponClass, _targetingSystems, _magazineInfo];

IVCS_Common_WeaponInfo setvariable [_weaponClass, _weaponInfo];

_weaponInfo