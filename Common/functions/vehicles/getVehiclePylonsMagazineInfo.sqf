params ["_vehicle"];

private _pylonsInfo = (getAllPylonsInfo _vehicle) apply { 
    private _pylonName = _x select 1;
    private _pylonMagazine = _x select 3;
    private _pylonMagazineAmmoCount = _x select 4;

    [_pylonName, [_pylonMagazine, _pylonMagazineAmmoCount]]
};

createHashMapFromArray _pylonsInfo