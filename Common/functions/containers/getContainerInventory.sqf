params ["_vehicle"];

// array of [weapon, muzzle, flashlight, optics, [primarymag, ammo count], [secondarymag, ammo count], bipod]
private _weapons = weaponsItemsCargo _vehicle;
private _magazines = magazinesAmmoCargo _vehicle;
private _items = itemcargo _vehicle;

private _containers = (everycontainer _vehicle) apply {
    private _containerClass = _x select 0;
    private _containerType = [_containerClass] call IVCS_Common_getContainerType;
    [_containerClass, _containerType, [_x select 1] call IVCS_Common_getContainerInventory]
};

_items = _items - (_containers apply {_x select 0});

createHashMapFromArray [
    ["weapons", _weapons],
    ["magazines", _magazines],
    ["items", _items],
    ["containers", _containers]
]
