params ["_vehicleClass"];

private _turretPaths = [_vehicleClass,[]] call bis_fnc_getturrets;
private _turretInfo = _turretPaths apply {
    private _turretPath = _x;
    private _turretConfig = [_vehicleClass, _turretPath] call BIS_fnc_turretConfig;
    private _turretWeapons = getarray (_turretConfig >> "weapons"); 
    private _turretMagazines = getarray (_turretConfig >> "Magazines");

    // lets associate magazines with turrets

    private _turretWeaponsInfo = _turretWeapons apply {
        private _weaponInfo = [_x] call IVCS_Common_getWeaponInfo;
        private _compatibleMags = _weaponInfo select 2;
        private _availableCompatibleMags = [];
        {
            if (_x in _compatibleMags) then {
                _availableCompatibleMags pushback _x;
            };
        } foreach _turretMagazines;
        _turretMagazines = _turretMagazines - _availableCompatibleMags;

        [_x, _availableCompatibleMags]
    };

    [_turretPath, _turretWeaponsInfo]
};

_turretInfo