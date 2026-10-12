params ["_entity"];

private _active = _entity get "active";
if (_active) exitwith {};

private _position = _entity get "position";
private _entityID = _entity get "id";
private _entityHitpoints = _entity get "hitpoints";

private _vehicleClass = _entity get "class";
private _engineOn = _entity get "engineOn";
private _vehicleType = _entity get "vehicleType";

private _special = "NONE";
if (_engineOn && ((_position select 2) > 20) && { _vehicleType in ["helicopter","plane"] }) then {
    _special = "FLY";
};

private _spawnDir = 0;
private _commandingEntityID = _entity get "commandingEntity";
if (_commandingEntityID != "") then {
    private _commandingEntity = [_commandingEntityID] call IVCS_VirtualSpace_getEntity;
    private _currentWaypoint = [_commandingEntity] call IVCS_VirtualSpace_getEntityCurrentWaypoint;
    if (!isnil "_currentWaypoint") then {
        private _movePoints = _currentWaypoint get "movePoints";
        if (_movePoints isnotequalto []) then {
            _spawnDir = _position getDir (_movePoints select 0);
        };
    };
};

systemchat format ["Position: %1", _position];

private _vehicleObject = createVehicle [_vehicleClass, _position, [], 0, _special];
_vehicleObject allowdamage false;
_vehicleObject setdir _spawnDir;

// TODO: use Executions module, wait for profile to be unlocked then allow damage
[_vehicleObject] spawn {
    sleep 1;
    (_this select 0) allowdamage true;
};
_vehicleObject setvariable ["entityID", _entityID];

_vehicleObject engineOn _engineOn;

// apply hitpoint damages

{
    _x params ["_hitpoint","_damage"];

    _vehicleObject setHitPointDamage [_hitpoint,_damage, false];
} foreach _entityHitpoints;

private _inventory = _entity get "inventory";
[_vehicleObject, _inventory] call IVCS_Common_applyContainerInventory;

[_entity] call IVCS_VirtualSpace_Vehicle_applyWeaponsToVehicleObject;

_vehicleObject addEventHandler ["GetOut", IVCS_VirtualSpace_Vehicle_onUnitGetOut];
_vehicleObject addEventHandler ["Killed", IVCS_VirtualSpace_Vehicle_onVehicleDestroyed];

private _debug = IVCS_VirtualSpace_Controller get "debug";
if (_debug) then {
    private _debugMarker = _entity get "debugMarker";
    _debugMarker setMarkerAlpha 0.75;
};

_entity set ["object", _vehicleObject];
_entity set ["active", true];