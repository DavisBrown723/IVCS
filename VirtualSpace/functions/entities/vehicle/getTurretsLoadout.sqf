params ["_vehicleClass"];

private _vehicleTurretInfo = [_vehicleClass] call IVCS_Common_getVehicleTurrets;
_vehicleTurretInfo apply {
    private _turretPath = _x;
    _y params ["_turretWeapons", "_turretMagazines", "_turretPylons"];

    private _magazines = _turretMagazines apply {
        [_x, ([_x] call IVCS_Common_getMagazineInfo) select 1]
    };
    private _pylons = _turretPylons apply {
        private _magazine = _y select 0;
        private _ammo = if (_magazine == "") then { 0 } else {
            ([_magazine] call IVCS_Common_getMagazineInfo) select 1
        };
        [_x, _magazine, _ammo, _turretPath]
    };

    [_turretPath, +_turretWeapons, _magazines, _pylons]
}
