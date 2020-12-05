params ["_vehicleClass", "_position"];

if (_vehicleClass iskindof "Man") exitwith {
    diag_log format ["IVCS: createVehicleEntity - Cannot create vehicle entity from non-vehicle class"];
};

private _vehicleConfig = configfile >> "CfgVehicles" >> _vehicleClass;

private _vehicleType = [_vehicleClass] call IVCS_Common_findUnitType;
private _maxSpeed = getnumber (_vehicleConfig >> "maxSpeed");

private _hitpoints = [_vehicleConfig >> "HitPoints", 0] call BIS_fnc_returnChildren;
private _side = [_vehicleClass] call IVCS_Common_getVehicleSide;

private _vehicleEntity = [] call CBA_fnc_createNamespace;
_vehicleEntity setvariable ["timeLastUpdate", diag_tickTime];
_vehicleEntity setvariable ["delayedInitComplete", false];
_vehicleEntity setvariable ["active", false];
_vehicleEntity setvariable ["class", _vehicleClass];
_vehicleEntity setvariable ["vehicleType", _vehicleType];
_vehicleEntity setvariable ["position", _position];
_vehicleEntity setvariable ["side", _side];
_vehicleEntity setvariable ["engineOn", false];

_vehicleEntity setvariable ["assignedEntity", ""];
_vehicleEntity setvariable ["commandingEntity", ""];
_VehicleEntity setvariable ["entitiesInCargo", []];

_vehicleEntity setvariable ["object", objNull];
_vehicleEntity setvariable ["speedPerSecond", round (_maxSpeed * 0.15)];
_vehicleEntity setvariable ["hitpoints", _hitpoints apply {[configname _x, 0]}];

private _seatCount = 0;
private _vehicleSeats = [_vehicleClass] call IVCS_Common_findVehicleSeats;
private _seatAssignments = _vehicleSeats apply {
    _x params ["_seatType","_seatPaths"];

    _seatPaths = _seatPaths apply { [_x, ""] };
    _seatCount = _seatCount + (count _seatPaths);

    [_seatType, _seatPaths]
};
_vehicleEntity setvariable ["seatCount", _seatCount];
_vehicleEntity setvariable ["seats", _seatAssignments];

private _vehiclePylonInfo = [_vehicleClass] call IVCS_Common_getVehiclePylons;
private _vehiclePylons = _vehiclePylonInfo apply {
    private _pylonName = _x select 0;
    private _pylonMagazine = _x select 1;

    private _magazineInfo = [_pylonMagazine] call IVCS_Common_getMagazineInfo;
    private _magazineAmmoCount = _magazineInfo select 1;

    [_pylonName, _pylonMagazine, _magazineAmmoCount]
};
_vehicleEntity setvariable ["pylons", _vehiclePylons];

if (_vehicleType == "uav") then {
    _vehicleEntity setvariable ["entityType", "uav"];

    // _vehicleEntity setvariable ["update", "IVCS_VirtualSpace_Uav_update"];
    // _vehicleEntity setvariable ["spawn", "IVCS_VirtualSpace_Uav_spawn"];
    // _vehicleEntity setvariable ["despawn", "IVCS_VirtualSpace_Uav_despawn"];
    // _vehicleEntity setvariable ["unregister", "IVCS_VirtualSpace_Uav_unregister"];
    _vehicleEntity setvariable ["update", "IVCS_VirtualSpace_Vehicle_update"];
    _vehicleEntity setvariable ["spawn", "IVCS_VirtualSpace_Vehicle_spawn"];
    _vehicleEntity setvariable ["despawn", "IVCS_VirtualSpace_Vehicle_despawn"];
    _vehicleEntity setvariable ["unregister", "IVCS_VirtualSpace_Vehicle_unregister"];
} else {
    _vehicleEntity setvariable ["entityType", "vehicle"];

    _vehicleEntity setvariable ["update", "IVCS_VirtualSpace_Vehicle_update"];
    _vehicleEntity setvariable ["spawn", "IVCS_VirtualSpace_Vehicle_spawn"];
    _vehicleEntity setvariable ["despawn", "IVCS_VirtualSpace_Vehicle_despawn"];
    _vehicleEntity setvariable ["unregister", "IVCS_VirtualSpace_Vehicle_unregister"];
};

[_vehicleEntity] call IVCS_VirtualSpace_registerEntity;

private _debug = IVCS_VirtualSpace_Controller getvariable "debug";
private _debugMarker = if (_debug) then {
    [_vehicleEntity] call IVCS_VirtualSpace_createEntityDebugMarker;
} else {
    ""
};
_vehicleEntity setvariable ["debugMarker", _debugMarker];

_vehicleEntity