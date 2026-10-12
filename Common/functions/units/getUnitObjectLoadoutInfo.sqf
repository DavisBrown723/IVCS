params ["_unitObject"];

private _weapons = weapons _unitObject;
private _magazines = magazines _unitObject;
private _magazines = magazinesAmmo _unitObject;
_magazines pushback [currentMagazine _unitObject, _unitObject ammo (currentWeapon _unitObject)];

private _loadout = [];

{
    private _weapon = _x;
    private _weaponInfo = [_weapon] call IVCS_Common_getWeaponInfo;
    private _compatibleMagazines = _weaponInfo select 2;

    private _compatibleMagsInLoadout = [];

    private _i = 0;
    private _magsLeft = count _magazines;
    while {_i < _magsLeft} do {
        (_magazines select _i) params ["_magazineClass","_magazineAmmoCount"];

        if (_magazineClass in _compatibleMagazines) then {
            private _magazineInfo = [_magazineClass] call IVCS_Common_getMagazineInfo;
            private _magazineUses = _magazineInfo select 3;

            _compatibleMagsInLoadout pushback [_magazineClass, _magazineAmmoCount, _magazineUses];
            _magazines deleteat _i;
        } else {
            _i = _i + 1;
        };
    };

    _loadout pushback [_weapon, _compatibleMagsInLoadout];
} foreach _weapons;

_loadout