params ["_vehicleClass"];

private _existingInventory = IVCS_Common_VehicleConfigInventories get _vehicleClass;
if (!isnil "_existingInventory") exitwith {
    _existingInventory
};

private _vehicleConfig = configfile >> "CfgVehicles" >> _vehicleClass;

private _containers = [];

// weapons

// array of [weapon, muzzle, flashlight, optics, [primarymag, ammo count], [secondarymag, ammo count], bipod]

private _cargoWeapons = [];
private _transportWeapons = ("true" configClasses (_vehicleConfig >> "TransportWeapons"));
{
    private _name = gettext (_x >> "weapon");
    private _countConfig = _x >> "count";
    private _count = if (isnumber _countConfig) then {
        getnumber _countConfig
    } else {
        call compile (gettext _countConfig);
    };

    private _weaponWithAttachments = [_name, "", "", "", [], [], ""]; // TODO: fill out values
    for "_i" from 0 to (_count - 1) do {
        _cargoWeapons pushback _weaponWithAttachments;
    };
} foreach _transportWeapons;

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

private _cargoItems = [];
private _transportItems = ("true" configClasses (_vehicleConfig >> "TransportItems"));
{
    private _name = gettext (_x >> "name");
    private _countConfig = _x >> "count";
    private _count = if (isnumber _countConfig) then {
        getnumber _countConfig
    } else {
        call compile (gettext _countConfig);
    };

    private _containerType = [_name] call IVCS_Common_getContainerType; // not exactly the best function but it works
    if (_containerType in ["uniform","vest"]) then {
        _containers pushback [_name, _count, _containerType];
    } else {
        for "_i" from 0 to (_count - 1) do {
            _cargoItems pushback _name;
        };
    };
} foreach _transportItems;

// backpacks

private _transportBackpacks = ("true" configClasses (_vehicleConfig >> "TransportBackpacks"));
{
    private _name = gettext (_x >> "backpack");
    private _countConfig = _x >> "count";
    private _count = if (isnumber _countConfig) then {
        getnumber _countConfig
    } else {
        call compile (gettext _countConfig);
    };

    _containers pushback [_name, _count, "backpack"];
} foreach _transportBackpacks;

// containers

private _cargoContainers = [];
{
    _x params ["_classname","_count","_containerType"];

    private _inventory = [_classname] call IVCS_Common_getContainerInventoryFromConfig;

    for "_i" from 0 to (_count - 1) do {
        _cargoContainers pushback [_classname, _containerType, _inventory];
    };
} foreach _containers;

private _inventory = createHashMapFromArray [
    ["weapons", _cargoWeapons],
    ["magazines", _cargoMagazines],
    ["items", _cargoItems],
    ["containers", _cargoContainers]
];

IVCS_Common_VehicleConfigInventories set [_vehicleClass, _inventory];

_inventory