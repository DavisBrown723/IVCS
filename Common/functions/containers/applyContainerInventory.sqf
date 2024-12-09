params ["_container","_inventory"];

[_container] call IVCS_Common_clearContainerInventory;

private _weapons = _inventory get "weapons";
{
    _container addWeaponWithAttachmentsCargoGlobal [_x, 1];
} foreach _weapons;

private _magazines = _inventory get "magazines";
{
    _container addMagazineAmmoCargo [_x select 0, 1, _x select 1];
} foreach _magazines;

private _items = _inventory get "items";
{
    _container addItemCargoGlobal [_x, 1];
} foreach _items;

// arma 3 seemingly offers no way to create container with items in parent container
// add containers
private _containers = _inventory get "containers";
{
    _x params ["_containerClass","_containerType"];
    
    if (_containerType == "backpack") then {
        _container addBackpackCargoGlobal [_containerClass, 1];
    } else {
        _container addItemCargoGlobal [_containerClass, 1];
    };
} foreach _containers;

// retrieve created containers and apply inventory
private _containersInParent = everycontainer _container;
reverse _containersInParent;
{
    private _containerClass = _x select 0;
    private _containerInventory = _x select 2;

    private _matchingContainerIndex = _containersInParent findif { (_x select 0) == _containerClass };
    if (_matchingContainerIndex != -1) then {
        private _matchingContainerObject = (_containersInParent deleteat _matchingContainerIndex) select 1;

        [_matchingContainerObject] call IVCS_Common_clearContainerInventory;
        [_matchingContainerObject, _containerInventory] call IVCS_Common_applyContainerInventory;
    } else {
        hint "IVCS_Common_applyContainerInventory: no matching container found";
    };
} foreach _containers;