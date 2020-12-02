params ["_unitClass"];

private _cfgVehicles = configfile >> "CfgVehicles";

private _cachedUnitInfo = IVCS_Common_AmmoInfo getvariable _unitClass;
if (!isnil "_cachedUnitInfo") exitwith { _cachedUnitInfo };

private _unitConfig = _cfgVehicles >> _unitClass;
private _weapons = getarray (_unitConfig >> "weapons") - ["Throw","Put","Binocular"];
private _magazines = getarray (_unitConfig >> "magazines");

// add weapons / magazines from backpack

private _backpack = gettext (_unitConfig >> "backpack");
private _backpackCargo = [_backpack, false, true, true] call IVCS_Common_getBackpackCargo;
_backpackCargo params ["_backpackItems","_backpackMags","_backpackWeapons"];

{_weapons pushbackunique _x} foreach _backpackWeapons;
_magazines append _backpackMags;

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
        if (isnil {_magazines select _i}) then {
            systemchat format ["Select %1 from %2", _i, count _magazines];
        };
        private _magazineClass = _magazines select _i;
        
        if (_magazineClass in _weaponCompatibleMags) then {
            private _magazineInfo = [_magazineClass] call IVCS_Common_getMagazineInfo;
            private _magazineSize = _magazineInfo select 1;
            private _magazineUses = _magazineInfo select 3;

            _compatibleMagsInLoadout pushback [_magazineClass,_magazineSize,_magazineUses];
            _magazines deleteat _i;
            _magsLeft = _magsLeft - 1;
        } else {
            _i = _i + 1;
        };
    };

    _loadout pushback [_weaponClass, _compatibleMagsInLoadout];
} foreach _weapons;

IVCS_Common_UnitInfo setvariable [_unitClass, _loadout];

_loadout