params ["_entity"];

private _active = _entity getvariable "active";
if (_active) exitwith {};

private _position = _entity getvariable "position";
private _entityID = _entity getvariable "id";
private _entityHitpoints = _entity getvariable "hitpoints";

private _vehicleClass = _entity getvariable "class";
private _engineOn = _entity getvariable "engineOn";
private _vehicleType = _entity getvariable "vehicleType";

private _special = "NONE";
if (_engineOn && ((_position select 2) > 20) && { _vehicleType in ["helicopter","plane"] }) then {
    _special = "FLY";
};

private _spawnDir = 0;
private _commandingEntityID = _entity getvariable "commandingEntity";
if (_commandingEntityID != "") then {
    private _commandingEntity = [_commandingEntityID] call IVCS_VirtualSpace_getEntity;
    private _movePoints = _commandingEntity getvariable "movePoints";
    if (count _movePoints > 1) then {
        _spawnDir = (_movePoints select 0) getDir (_movePoints select 1);
    };
};

private _vehicleObject = createVehicle [_vehicleClass, _position, [], 0, _special];
_vehicleObject allowdamage false;
_vehicleObject setdir _spawnDir;
[_vehicleObject] spawn {
    sleep 1;
    (_this select 0) allowdamage true;
};
_vehicleObject setvariable ["entityID", _entityID];

_vehicleObject engineOn _engineOn;

{
    _x params ["_hitpoint","_damage"];
    
    _vehicleObject setHitPointDamage [_hitpoint,_damage, false];
} foreach _entityHitpoints;

_vehicleObject addEventHandler ["GetOut", IVCS_VirtualSpace_Vehicle_onUnitGetOut];
_vehicleObject addEventHandler ["Killed", IVCS_VirtualSpace_Vehicle_onVehicleDestroyed];

_entity setvariable ["object", _vehicleObject];

private _debug = IVCS_VirtualSpace_Controller getvariable "debug";
if (_debug) then {
    private _debugMarker = _entity getvariable "debugMarker";
    _debugMarker setMarkerAlpha 0.75;
};

_entity setvariable ["active", true];