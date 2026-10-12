params ["_vehicleClass"];

private _vehicleTurretInfo = [_vehicleClass] call IVCS_Common_getVehicleTurrets;
private _vehicleTurrets = _vehicleTurretInfo apply {
    private _turretPath = _x;
    
    _y params ["_turretWeapons","_turretMagazines","_turretPylons"];

    private _turretMagazinesLoadout = _turretMagazines apply {
        private _magazineInfo = [_x] call IVCS_Common_getMagazineInfo;
        private _magazineAmmoCount = _magazineInfo select 1;

        [_x, _magazineAmmoCount]
    };

    private _turretPylonLoadout = _turretPylons apply {
        private _defaultMagazine = _y select 0;

        private _defaultMagazineInfo = [_defaultMagazine] call IVCS_Common_getMagazineInfo;
        private _defaultMagazineAmmoCount = _defaultMagazineInfo select 1;

        [_x, _defaultMagazine, _defaultMagazineAmmoCount]
    };

    [_turretPath, _turretWeapons, _turretMagazinesLoadout, _turretPylonLoadout]
};

_vehicleTurrets