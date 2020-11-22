params ["_unitClass"];

private _cfgVehicles = configfile >> "CfgVehicles";

private _unitConfig = _cfgVehicles >> _unitClass;
private _weapons = getarray (_unitConfig >> "weapons") - ["Throw","Put","Binocular"];
private _magazines = getarray (_unitConfig >> "magazines");

private _backpack = gettext (_unitConfig >> "backpack");
private _backpackCargo = [_backpack, false, true, true] call IVCS_Common_getBackpackCargo;
_backpackCargo params ["_backpackItems","_backpackMags","_backpackWeapons"];
{_weapons pushbackunique _x} foreach _backpackWeapons;
_magazines append _backpackMags;

private _cfgWeapons = configfile >> "CfgWeapons";
private _CfgMagazines = configfile >> "CfgMagazines";

private _loadout = [];

{
    private _weaponClass = _x;
    private _weaponInfo = [_weaponClass] call IVCS_Common_getWeaponInfo;
    private _weaponCompatibleMags = _weaponInfo select 2;

    private _compatibleMagsInLoadout = [];

    private _i = 0;
    private _magsLeft = count _magazines;
    while {_i < _magsLeft} do {
        private _magClass = _magazines select _i;
        if (_magClass in _weaponCompatibleMags) then {
            private _magConfig = _CfgMagazines >> _magClass;
            private _magSize = getnumber (_magConfig >> "count");

            _compatibleMagsInLoadout pushback [_magClass, _magSize];
            _magazines deleteat _i;
        } else {
            _i = _i + 1;
        };
    };

    _loadout pushback [_weaponClass, _compatibleMagsInLoadout];
} foreach _weapons;+

_loadout