params ["_vehicleEntity"];

private _vehicleObject = _vehicleEntity get "object";
// Pylons own their magazines; clear them before clearing ordinary turret ammo.
{
    _vehicleObject setPylonLoadout [_x select 1, ""];
} forEach getAllPylonsInfo _vehicleObject;
private _magazines = (magazinesAllTurrets [_vehicleObject, true]) apply { _x select [0, 2] };
{
    _vehicleObject removeMagazinesTurret _x;
} forEach (_magazines arrayIntersect _magazines);

{
    _x params ["_turretPath", "_turretWeapons", "_turretMagazines", "_turretPylons"];
    {
        _x params ["_magazine", "_ammo"];
        _vehicleObject addMagazineTurret [_magazine, _turretPath, _ammo];
    } forEach _turretMagazines;

    {
        _x params ["_pylonName", "_magazine", "_ammo", "_pylonTurret"];
        _vehicleObject setPylonLoadout [_pylonName, _magazine, true, _pylonTurret];
        _vehicleObject setAmmoOnPylon [_pylonName, _ammo];
    } forEach _turretPylons;
} forEach (_vehicleEntity get "turrets");
