params ["_vehicleClass"];

private _existingInventory = IVCS_Common_VehicleConfigInventories get _vehicleClass;
if (!isnil "_existingInventory") exitwith {
    _existingInventory
};

private _vehicleConfig = configfile >> "CfgVehicles" >> _vehicleClass;

// weapons

private _cargoWeapons = ("true" configClasses (_vehicleConfig >> "TransportWeapons")) apply {
    private _name = gettext (_x >> "weapon");
    private _countConfig = _x >> "count";
    private _count = if (isnumber _countConfig) then {
        getnumber _countConfig
    } else {
        call compile (gettext _countConfig);
    };

    [_name, _count]
};

// magazines

private _cargoMagazines = ("true" configClasses (_vehicleConfig >> "TransportMagazines")) apply {
    private _name = gettext (_x >> "magazine");
    private _countConfig = _x >> "count";
    private _count = if (isnumber _countConfig) then {
        getnumber _countConfig
    } else {
        call compile (gettext _countConfig);
    };

    [_name, _count]
};

// items

private _cargoItems = ("true" configClasses (_vehicleConfig >> "TransportItems")) apply {
    private _name = gettext (_x >> "name");
    private _countConfig = _x >> "count";
    private _count = if (isnumber _countConfig) then {
        getnumber _countConfig
    } else {
        call compile (gettext _countConfig);
    };

    [_name, _count]
};

// backpacks

private _cargoBackpacks = ("true" configClasses (_vehicleConfig >> "TransportBackpacks")) apply {
    private _name = gettext (_x >> "backpack");
    private _countConfig = _x >> "count";
    private _count = if (isnumber _countConfig) then {
        getnumber _countConfig
    } else {
        call compile (gettext _countConfig);
    };

    [_name, _count]
};

private _inventory = createHashMapFromArray [
    ["weapons", _cargoWeapons],
    ["magazines", _cargoMagazines],
    ["items", _cargoItems],
    ["backpacks", _cargoBackpacks]
];

IVCS_Common_VehicleConfigInventories set [_vehicleClass, _inventory];

_inventory