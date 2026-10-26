params ["_entity"];

private _active = _entity get "active";
if (!_active || { _entity get "simulationTransition" }) exitWith {};
_entity set ["simulationTransition",true];
[_entity,false] call IVCS_Combat_setHelicopterPassHold;
(_entity get "object") allowDamage false;
_entity set ["flightHeading",getDir (_entity get "object")];
_entity set ["flightVelocity",velocity (_entity get "object")];
if ((_entity get "combatID") != "") then {
    (((IVCS_VirtualSpace_Controller get "combat") get "engagements") get (_entity get "combatID")) set ["mode","despawning"];
};

// Break group/vehicle recursion before visiting connected entities.
[_entity, false] call IVCS_VirtualSpace_setEntityActive;
[_entity, getPos (_entity get "object")] call IVCS_VirtualSpace_setEntityPosition;

// despawn any connected entities first

private _commandingEntityID = _entity get "commandingEntity";
private _entitiesInCargo = _entity get "entitiesInCargo";
{
    private _connectedEntity = [_x] call IVCS_VirtualSpace_getEntity;
    if (!isNil "_connectedEntity") then {
        private _despawnFunc = missionnamespace getvariable (_connectedEntity get "despawn");
        [_connectedEntity] call _despawnFunc;
    };
} foreach (_entitiesInCargo + [_commandingEntityID]);

// despawn this entity

private _vehicleObject = _entity get "object";
_entity set ["damage",damage _vehicleObject];

private _hitpoints = _entity get "hitpoints";
{
    private _hitpoint = _x select 0;

    private _hitpointDamage = _vehicleObject getHitPointDamage _hitpoint;
    _x set [1, _hitpointDamage];
} foreach _hitpoints;
[_entity] call IVCS_Combat_updateVehicleMobility;

private _inventory = [_vehicleObject] call IVCS_Common_getContainerInventory;
_entity set ["inventory", _inventory];

[_entity] call IVCS_VirtualSpace_Vehicle_storeVehicleObjectWeapons;

_entity set ["engineOn", isEngineOn _vehicleObject];

private _nativeGroups = (_entity get "nativeCrew") apply { group _x };
{ deleteVehicle _x; } forEach (_entity get "nativeCrew");
{ deleteGroup _x; } forEach (_nativeGroups arrayIntersect _nativeGroups);
(_entity get "nativeCrew") resize 0;
deletevehicle _vehicleObject;
_entity set ["object", objNull];
_entity set ["nativeAirTarget",objNull]; _entity set ["nativeAirDestination",[]];
_entity set ["simulationTransition",false];
if ((_entity get "combatID") != "") then { [_entity] call IVCS_Combat_onDespawn; };

private _debug = IVCS_VirtualSpace_Controller get "debug";
if (_debug) then {
    private _debugMarker = _entity get "debugMarker";
    _debugMarker setMarkerAlpha 0.35;
};
