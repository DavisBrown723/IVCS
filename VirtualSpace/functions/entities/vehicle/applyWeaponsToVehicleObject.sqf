params ["_vehicleEntity"];

private _vehicleObject = _entity get "object";
private _turrets = _entity get "turrets";
{
    _x params ["_turretPath","_turretWeapons","_turretMagazines","_turretPylons"];

    {
        _x params ["_magazine","_ammo"];

        _vehicleObject addMagazineTurret [_magazine, _turretPath, _ammo];
    } foreach _turretMagazines;

    {
        _x params ["_pylonName","_magazine","_ammo"];

        _vehicleObject setPylonLoadout [_pylonName, _magazine];
        _vehicleObject setAmmoOnPylon [_pylonName, _ammo];
    } foreach _turretPylons;
} foreach _turrets;