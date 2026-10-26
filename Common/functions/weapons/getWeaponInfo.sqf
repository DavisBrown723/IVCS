params ["_weaponClass"];

_weaponClass = IVCS_Common_WeaponAliases getOrDefault [_weaponClass, _weaponClass];

private _cachedWeaponInfo = IVCS_Common_WeaponInfo get _weaponClass;
if (!isnil "_cachedWeaponInfo") exitwith { _cachedWeaponInfo };

private _weaponConfig = configfile >> "CfgWeapons" >> _weaponClass;
private _compatibleMags = getArray (_weaponConfig >> "magazines");
_compatibleMags append (compatibleMagazines [_weaponClass, "this"]);
_compatibleMags = _compatibleMags arrayIntersect _compatibleMags;
private _weaponLockSystem = getnumber (_weaponConfig >> "weaponLockSystem");

private _targetingSystems = if (_weaponLockSystem != 0) then {
    private _targetingSystemFlags = _weaponLockSystem call BIS_fnc_bitflagsToArray;
    _targetingSystemFlags apply {
        switch (_x) do {
            case 1: { "visual" };
            case 2: { "ir" };
            case 4: { "laser" };
            case 8: { "radar" };
        };
    };
} else {
    []
};

private _allMagazines = (_compatibleMags + (compatibleMagazines _weaponClass));
_allMagazines = _allMagazines arrayIntersect _allMagazines;
private _weaponInfo = [_weaponClass, _targetingSystems, _compatibleMags, _allMagazines];

IVCS_Common_WeaponInfo set [_weaponClass, _weaponInfo];

_weaponInfo
