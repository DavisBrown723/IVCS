params ["_entity"];

private _ready = false;
isNil {
    if (_entity get "active" || { _entity get "simulationTransition" }) exitWith {};
    if ((_entity get "combatID") != "") then { [_entity] call IVCS_Combat_flushPending; };
    if ((_entity get "damage") >= 1) exitWith {};
    _entity set ["simulationTransition",true];
    if ((_entity get "combatID") != "") then {
        (((IVCS_VirtualSpace_Controller get "combat") get "engagements") get (_entity get "combatID")) set ["mode","spawning"];
    };
    _ready = true;
};
if (!_ready) exitWith {};

private _position = _entity get "position";
private _entityID = _entity get "id";
private _entityHitpoints = _entity get "hitpoints";

private _vehicleClass = _entity get "class";
private _engineOn = _entity get "engineOn";
private _vehicleType = _entity get "vehicleType";

private _special = "NONE";
if (_vehicleType=="helicopter" && {(_position select 2)>4} || {_engineOn && {(_position select 2)>20} && {_vehicleType=="plane"}}) then {
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

if (_vehicleType=="helicopter") then {_spawnDir=_entity get "flightHeading"};
private _vehicleObject = createVehicle [_vehicleClass, _position, [], 0, _special];
_vehicleObject allowdamage false;
_vehicleObject setdir _spawnDir;

_vehicleObject setvariable ["entityID", _entityID];

_vehicleObject engineOn _engineOn;
if (_vehicleType=="helicopter" && {_special=="FLY"}) then {
    _vehicleObject setVelocity (_entity get "flightVelocity");
    _vehicleObject flyInHeight (_position select 2);
};

// Scripted hitpoint restoration also requires damage to be enabled.
_vehicleObject allowDamage true;
_vehicleObject setDamage [_entity get "damage",false];

{
    _x params ["_hitpoint","_damage"];

    _vehicleObject setHitPointDamage [_hitpoint,_damage, false];
} foreach _entityHitpoints;
_vehicleObject allowDamage false;

private _inventory = _entity get "inventory";
[_vehicleObject, _inventory] call IVCS_Common_applyContainerInventory;

_entity set ["object", _vehicleObject];
_entity set ["flightRestorePending",true];
if ((_entity get "entityType") == "uav") then {
    createVehicleCrew _vehicleObject;
    _entity set ["nativeCrew",crew _vehicleObject];
};
[_entity] call IVCS_VirtualSpace_Vehicle_applyWeaponsToVehicleObject;

if (_vehicleType=="helicopter") then {
    _vehicleObject addEventHandler ["Fired",{[_this select 0,_this select 7,_this select 5] call IVCS_Combat_onHelicopterFired}];
    _vehicleObject addEventHandler ["FiredNear",{[_this select 0,_this select 1] call IVCS_Combat_onHelicopterThreat}];
    _vehicleObject addEventHandler ["Hit",{[_this select 0,_this select 1] call IVCS_Combat_onHelicopterThreat}];
    _vehicleObject addEventHandler ["IncomingMissile",{[_this select 0,_this select 2] call IVCS_Combat_onHelicopterThreat}];
};
_vehicleObject addEventHandler ["GetOut", IVCS_VirtualSpace_Vehicle_onUnitGetOut];
_vehicleObject addEventHandler ["Killed", IVCS_VirtualSpace_Vehicle_onVehicleDestroyed];

private _debug = IVCS_VirtualSpace_Controller get "debug";
if (_debug) then {
    private _debugMarker = _entity get "debugMarker";
    _debugMarker setMarkerAlpha 0.75;
};

_entity set ["simulationTransition",false];
[_entity, true] call IVCS_VirtualSpace_setEntityActive;
if ((_entity get "combatID") != "") then { [_entity] call IVCS_Combat_onSpawn; };
// Begin the grace period only after the saved state has been restored.
[_vehicleObject] spawn {
    sleep 1;
    (_this select 0) allowDamage true;
};
