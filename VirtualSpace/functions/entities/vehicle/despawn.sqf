params ["_entity"];

private _active = _entity get "active";
if (!_active) exitwith {};

// despawn any connected entities first

private _commandingEntityID = _entity get "commandingEntity";
private _entitiesInCargo = _entity get "entitiesInCargo";
{
    private _connectedEntity = [_x] call IVCS_VirtualSpace_getEntity;
    private _despawnFunc = missionnamespace getvariable (_connectedEntity get "despawn");
    [_connectedEntity] call _despawnFunc;
} foreach (_entitiesInCargo + [_commandingEntityID]);

// despawn this entity

private _vehicleObject = _entity get "object";

private _hitpoints = _entity get "hitpoints";
{
    private _hitpoint = _x select 0;

    private _hitpointDamage = _vehicleObject getHitPointDamage _hitpoint;
    _x set [1, _hitpointDamage];
} foreach _hitpoints;

private _inventory = [_vehicleObject] call IVCS_Common_getContainerInventory;
_entity set ["inventory", _inventory];

[_entity] call IVCS_VirtualSpace_Vehicle_storeVehicleObjectWeapons;

_entity set ["engineOn", isEngineOn _vehicleObject];

deletevehicle _vehicleObject;
_entity set ["object", objNull];

private _debug = IVCS_VirtualSpace_Controller get "debug";
if (_debug) then {
    private _debugMarker = _entity get "debugMarker";
    _debugMarker setMarkerAlpha 0.35;
};

_entity set ["active", false];