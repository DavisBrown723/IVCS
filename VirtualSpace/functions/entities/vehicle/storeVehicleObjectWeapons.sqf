params ["_vehicleEntity"];

private _vehicleObject = _entity get "object";
private _turrets = _entity get "turrets";

private _turretMagazineMap = createHashMap;
{
    _X params ["_magazineClassname","_turretPath","_ammoCount"];

    private _existingTurretMagazines = _turretMagazineMap getOrDefault [_turretPath, [], true];
    _existingTurretMagazines pushback [_magazineClassname, _ammoCount];
} foreach (magazinesAllTurrets [_vehicleObject, true]);

private _pylonsMagazineInfo = [_vehicleObject] call IVCS_Common_getVehiclePylonsMagazineInfo;
private _turrets = _entity get "turrets";
{
    _x params ["_turretPath","_turretWeapons","_turretMagazines","_turretPylons"];

    private _magazinesForTurret = _turretMagazineMap get _turretPath;

    _turretMagazines resize 0;
    _turretMagazines append _magazinesForTurret;

    {
        _x params ["_pylonName","_magazine","_ammo"];

        (_pylonsMagazineInfo get _pylonName) params ["_pylonMagazine","_pylonMagazineAmmoCount"];

        _x set [1, _pylonMagazine];
        _x set [2, _pylonMagazineAmmoCount];
    } foreach _turretPylons;
} foreach _turrets;