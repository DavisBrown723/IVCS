params ["_backpackClass","_includeItems","_includeMagazines","_includeWeapons"];

private _backpackConfig = configfile >> "CfgVehicles" >> _backpackClass;
private _items = [];
private _magazines = [];
private _weapons = [];

if (_includeItems) then {
    private _backpackItems = _backpackConfig >> "transportItems";
    for "_i" from 0 to (count _backpackItems - 1) do {
        private _transportItemClass = _backpackItems select _i;
        if (isclass _transportItemClass) then {
            private _itemClass = gettext (_transportItemClass >> "item");
            private _itemCount = getnumber (_transportItemClass >> "count");

            _items pushback _itemClass;
        };
    };
};

if (_includeMagazines) then {
    private _backpackMagazines = _backpackConfig >> "transportMagazines";
    for "_i" from 0 to (count _backpackMagazines - 1) do {
        private _transportMagazineClass = _backpackMagazines select _i;
        if (isclass _transportMagazineClass) then {
            private _magazineClass = gettext (_transportMagazineClass >> "magazine");
            private _magazineCount = getnumber (_transportMagazineClass >> "count");

            _magazines pushback _magazineClass;
        };
    };
};

if (_includeWeapons) then {
    private _backpackWeapons = _backpackConfig >> "transportWeapons";
    for "_i" from 0 to (count _backpackWeapons - 1) do {
        private _transportWeaponClass = _backpackWeapons select _i;
        if (isclass _transportWeaponClass) then {
            private _weaponClass = gettext (_transportWeaponClass >> "weapon");
            private _weaponCount = getnumber (_transportWeaponClass >> "count");

            _weapons pushback _weaponClass;
        };
    };
};

[_items, _magazines, _weapons]